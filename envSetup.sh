#!/bin/bash

InstallPrereqs() {
    echo "installing Docker"
    apt update > run.log 2>&1
    apt remove -y docker >>  run.log 2>&1
    apt install -y docker.io >> run.log 2>&1

    if [[ !$SKIP_LETS_ENCRYPT ]]; then
        echo "installing ACME certbot"
        snap install core
        snap refresh core
        snap install --classic certbot
        ln -s /snap/bin/certbot /usr/bin/certbot
    fi

    echo "disabling resolved.service"
    sed -i "s/#DNS=/DNS=1.1.1.1/g" /etc/systemd/resolved.conf
    sed -i "s/#DNSStubListener=yes/DNSStubListener=no/g" /etc/systemd/resolved.conf
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    systemctl stop systemd-resolved
}

Help() {
    echo "Usage: sudo ./envSetup.sh [-i|-h|-r]"
    echo "  -i : install pre-reqs before configuring and setting up the environment"
    echo "  -r : remove the configuration. Doesn't uninstall pre-reqs or undo steps to deisable systemd-resolved"
    echo "  -h : print out this help and usage message :)"
    echo ""
    echo "Note: this command needs root for installation commands, for running docker commands, "
    echo "      and for editing files/folders at /etc/pki and /var/lib/docker/volumes. Alternatively, "
    echo "      you could create a user with permissions to run these commands and run this script as "
    echo "      that user instead."
    echo ""
    echo "Before running, set the following environment variables in the file 'vars':"
    echo "	SERVER_NAME=example"
    echo "	DOMAIN_NAME=example.com"
    echo "	SERVER_PRIVATE_IP=10.x.x.x"
    echo "	SERVER_PUBLIC_IP=20.x.x.x"
    echo ""
    echo "Optional"
    echo "  export SKIP_LETS_ENCRYPT=1 - to skip the letsencrypt automation steps"
    echo "  export SKIP_CERT_GENERATION=1 - to skip generating new PKI certs"
}

Uninstall() {
    echo "removing docker containers"
	docker stop nginx
	docker rm nginx

    docker stop unbound
    docker rm unbound

    docker stop webService
    docker rm webService

    echo "removing docker volumes"
    docker volume rm nginx-vol
    docker volume rm unbound

    echo "removing /etc/pki/tls folder"
    rm -rf /etc/pki/tls
}

VerifyEnvironmentVars() {
    if [ -z $SERVER_NAME ]; then
        echo "MISSING SERVER NAME... Aborting."
        exit
    fi
    if [ -z $DOMAIN_NAME ]; then
        echo "MISSING DOMAIN NAME... Aborting."
        exit
    fi
    if [ -z $SERVER_PRIVATE_IP ]; then
        echo "MISSING PRIVATE IP... Aborting."
        exit
    fi
    if [ -z $SERVER_PUBLIC_IP ]; then
        echo "MISSING PUBLIC IP... Aborting."
        exit
    fi
}

ReplaceNames() {
    echo "Injecting Environment variables"

    sed -i "s/##SERVER_NAME##/${SERVER_NAME}/g" *.d/*.conf
    sed -i "s/##DOMAIN_NAME##/${DOMAIN_NAME}/g" *.d/*.conf
    sed -i "s/##SERVER_PRIVATE_IP##/${SERVER_PRIVATE_IP}/g" *.d/*.conf
    sed -i "s/##SERVER_PUBLIC_IP##/${SERVER_PUBLIC_IP}/g" *.d/*.conf
}

###########################################################################################
#                                                                                         #
#                           Simple Env Setup with Docker                                  #
#                                                                                         #
###########################################################################################

ConfigureCerts() {
    # push current directory
    current_dir=$(pwd)

    # setup PKI folder structure
    mkdir /etc/pki/tls
    mkdir /etc/pki/tls/certs
    mkdir /etc/pki/tls/req
    mkdir /etc/pki/tls/private
    
    # copy config into the tls folder structure
    cp openssl.conf.d/* /etc/pki/tls

    cd /etc/pki/tls

    # generate self-signed root CA
    openssl genrsa -out private/cakey.pem 4096
    openssl req -new -x509 -days 3650 -extensions v3_ca -config cacert.conf -key private/cakey.pem \
        -out certs/cacert.pem 

    # generate leaf from our CA
    openssl genrsa -out private/server.key 4096
    openssl req -new -key private/server.key -out req/server.csr -config openssl.conf
    openssl x509 -req -days 365 -in req/server.csr -CA certs/cacert.pem -CAkey private/cakey.pem \
        -CAcreateserial -out certs/server.pem -extensions req_ext -extfile openssl.conf

    # generate untrusted leaf cert
    openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -config untrusted.conf -nodes -out \
        certs/untrusted.pem -keyout private/untrusted.key

    if [[ !$SKIP_LETS_ENCRYPT ]]; then
        certbot certonly --standalone

        cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem certs/letsencrypt.pem
        cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem private/letsencrypt.key

        openssl pkcs12 -export -out private/letsencrypt.pfx -inkey private/letsencrypt.key \
            -in certs/letsencrypt.pem -nodes -password pass:
    fi

    cd $current_dir
    # pop current directory
}

ConfigureUnbound() {
    # create the unbound volume
    docker volume create unbound

    # run the unbound container
    docker run -d \
        --name=unbound \
        -v unbound:/opt/unbound/etc/unbound/ \
        -p 53:53/tcp \
        -p 53:53/udp \
        --restart=unless-stopped \
        mvance/unbound:latest

    # copy in necessary config files
    cp unbound.conf.d/a-records.conf /var/lib/docker/volumes/unbound/_data/a-records.conf
    # restart to apply config change
    docker restart unbound
}

ConfigureNginx() {
    # create volume
    docker volume create nginx-vol

    # copy config files, certs, and pages to serve up
    cp -r nginx.conf.d /var/lib/docker/volumes/nginx-vol/_data/nginx.conf.d
    cp -r /etc/pki/tls/certs /var/lib/docker/volumes/nginx-vol/_data/certs
    cp -r /etc/pki/tls/private /var/lib/docker/volumes/nginx-vol/_data/private
    cp -r nginx_data /var/lib/docker/volumes/nginx-vol/_data/data

	# run the containers
	docker run -d \
		--name=nginx \
		--mount source=nginx-vol,destination=/etc/volume \
		-p 443:443 \
		--restart=unless-stopped \
		-v /var/lib/docker/volumes/nginx-vol/_data/nginx.conf.d/nginx.conf:/etc/nginx/nginx.conf:ro \
		nginx
}

###########################################################################################
#                                                                                         #
#                                    JS SPA env setup                                     #
#                                                                                         #
###########################################################################################

BuildAndRunWebService() {
    current_dir=$(pwd)

    cd sampleWebService

    docker build -t samplewebservice .

    docker run -d \
        --name=webService \
        --restart=unless-stopped \
        -p 80:80 \
        samplewebservice

    cd $current_dir
}

###########################################################################################
#                                                                                         #
#                                          Main()                                         #
#                                                                                         #
###########################################################################################

. vars

if [[ $1 == "-h" ]]; then
    Help
elif [[ $1 == "-r" ]]; then
    Uninstall
else
    if [[ $1 == "-i" ]]; then
        InstallPrereqs
    fi

    # setup server name
    VerifyEnvironmentVars
    ReplaceNames

    if [[ !$SKIP_CERT_GENERATION ]]; then
        ConfigureCerts
    fi

    ConfigureUnbound
    ConfigureNginx
    BuildAndRunWebService
fi