#!/bin/bash

InstallPrereqs() {
    echo "installing Docker"
    apt update > run.log 2>&1
    apt remove -y docker >>  run.log 2>&1
    apt install -y docker.io >> run.log 2>&1

    echo "disabling resolved.service"
    sed -i "s/#DNS=/DNS=1.1.1.1/g" /etc/systemd/resolved.conf
    sed -i "s/#DNSStubListener=yes/DNSStubListener=no/g" /etc/systemd/resolved.conf
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    systemctl stop systemd-resolved

	cd acme.sh

	./acme.sh --install -m $EMAIL
	
	cd ..
}

Help() {
    echo "Usage: sudo ./envSetup.sh [-i|-h|-r|-p]"
    echo "  -i : install pre-reqs before configuring and setting up the environment"
    echo "  -r : remove the configuration. Doesn't uninstall pre-reqs or undo steps to deisable systemd-resolved"
    echo "  -p : install and configure a squid proxy"
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
    echo "	SERVER_PUBLIC_IP=20.x.x.x"
    echo ""
    echo "  EMAIL=example@example.com"
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

    docker stop proxy
    docker rm proxy

    echo "removing docker volumes"
    docker volume rm nginx-vol
    docker volume rm unbound

    echo "removing /etc/pki/tls folder"
    rm -rf /etc/pki/tls

    git reset --hard
}

VerifyEnvironmentVars() {
    fail=1
    if [ -z $SERVER_NAME ]; then
        echo "MISSING SERVER NAME... Aborting."
        fail=0
    fi
    if [ -z $DOMAIN_NAME ]; then
        echo "MISSING DOMAIN NAME... Aborting."
        fail=0
    fi
    if [ -z $SERVER_PUBLIC_IP ]; then
        echo "MISSING PUBLIC IP... Aborting."
        fail=0
    fi
    if [ -z $EMAIL ]; then
        echo "MISSING EMAIL... Aborting."
        fail=0
    fi
    if [ -z $PROXY_ALLOWED_NAMES ]; then
        echo "MISSING PROXY ALLOWED NAMES, no urls will be allowed through the proxy."
    fi
    if [ -z $PROXY_BYPASS_NAMES ]; then
        echo "MISSING PROXY BYPASS NAMES, all urls will have to go through the proxy."
    fi
    if [ -z fail ]
        exit
    fi
}

ReplaceNames() {
    echo "Injecting Environment variables"

    sed -i "s/##SERVER_NAME##/${SERVER_NAME}/g" *.d/*.conf
    sed -i "s/##DOMAIN_NAME##/${DOMAIN_NAME}/g" *.d/*.conf
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
		/root/.acme.sh/acme.sh --upgrade
		/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
		/root/.acme.sh/acme.sh --register-account

		/root/.acme.sh/acme.sh --upgrade --update-account --accountemail $EMAIL

		/root/.acme.sh/acme.sh --issue --alpn -d $DOMAIN_NAME --preferred-chain "ISRG ROOT X1"

		cp /root/.acme.sh/$DOMAIN_NAME/fullchain.cer certs/letsencrypt.pem
		cp /root/.acme.sh/$DOMAIN_NAME/$DOMAIN_NAME.key private/letsencrypt.key
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

    UNBOUND_IP=$(docker container inspect -f "{{ .NetworkSettings.Networks.bridge.IPAddress }}" unbound)
}

ConfigureNginx() {
    # create volume
    docker volume create nginx-vol

    # copy config files, certs, and pages to serve up
    cp -r nginx.conf.d /var/lib/docker/volumes/nginx-vol/_data/nginx.conf.d
    cp -r /etc/pki/tls/certs /var/lib/docker/volumes/nginx-vol/_data/certs
    cp -r /etc/pki/tls/private /var/lib/docker/volumes/nginx-vol/_data/private
    cp -r nginx_data /var/lib/docker/volumes/nginx-vol/_data/data

	# run the containers on the docker subnet
	docker run -d \
		--name=nginx \
		--mount source=nginx-vol,destination=/etc/volume \
		--restart=unless-stopped \
		-v /var/lib/docker/volumes/nginx-vol/_data/nginx.conf.d/nginx.conf:/etc/nginx/nginx.conf:ro \
		nginx

    NGINX_IP=$(docker container inspect -f "{{ .NetworkSettings.Networks.bridge.IPAddress }}" nginx)
    sed -i "s/##NGINX_IP##/${NGINX_IP}/g" *.d/*.conf
}

###########################################################################################
#                                                                                         #
#                             Simple Squid Proxy Setup                                    #
#                                                                                         #
###########################################################################################

BuildAndRunProxy() {
    PROXY_BYPASS_NAME_TEMPLATE=$(cat proxy/proxy_bypass_name_tamplate)
    
    for pan in "${PROXY_BYPASS_NAMES[@]}"; do
        echo "Proxy bypass name: $pan"
        panline=$(echo $PROXY_BYPASS_NAME_TEMPLATE | sed -e "s/\bPROXY_BYPASS_NAME\b/$pan/g")
        sed -i -e "s#// PROXY_BYPASS_NAMES#$panline#g" nginx_data/tunnel.pac;
    done

    for pan in "${PROXY_ALLOWED_NAMES[@]}"; do
        echo "$pan" >> proxy/etc/squid/allowlist
    done
    docker build . --build-arg PROXY_PORT=3128 --tag ubuntu:squid --file proxy/Dockerfile 
    docker run -d \
            --name proxy \
            --restart always \
            --volume /etc/squid \
            --dns "$UNBOUND_IP" \
            --dns-search "$DOMAIN_NAME" \
            ubuntu:squid

    PROXY_IP=$(docker container inspect -f "{{ .NetworkSettings.Networks.bridge.IPAddress }}" proxy)
    sed -i "s/##PROXY_IP##/${PROXY_IP}/g" *.d/*.conf
    sed -i "s/PROXY_IP/${PROXY_IP}/g" nginx_data/tunnel.pac
    sed -i "s/# local-data/local-data/g" unbound.conf.d/a-records.conf
    cp unbound.conf.d/a-records.conf /var/lib/docker/volumes/unbound/_data/a-records.conf
    docker restart unbound

    docker cp proxy/etc/squid/squid.conf proxy:/etc/squid/squid.conf
    docker cp proxy/etc/squid/allowlist proxy:/etc/squid/allowlist
    docker restart proxy
}

PrintConf() {
    echo "=================== Use the following to configure Microsoft Tunnel Server ======================="
    echo "DNS server: $UNBOUND_IP"
    echo "Proxy server names: $PROXY_IP proxy.$DOMAIN_NAME"
    echo "Proxy server port: 3128"
    echo "PAC URL: http://$DOMAIN_NAME/tunnel.pac"
    echo "Proxy bypassed names: ${PROXY_BYPASS_NAMES[*]}"
    echo "Proxy allowed names: ${PROXY_ALLOWED_NAMES[*]}"
    echo "=================================================================================================="
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

    WEBSERVICE_IP=$(docker container inspect -f "{{ .NetworkSettings.Networks.bridge.IPAddress }}" webService)
    sed -i "s/##WEBSERVICE_IP##/${WEBSERVICE_IP}/g" *.d/*.conf
}

###########################################################################################
#                                                                                         #
#                              Install Tunnel Appliance                                   #
#                                                                                         #
###########################################################################################
InstallTunnelAppliance() {
    # Download the installation script 
    wget --output-document=mstunnel-setup https://aka.ms/microsofttunneldownload
    chmod +x ./mstunnel-setup

    # make the correct directories
    mkdir /etc/mstunnel
    mkdir /etc/mstunnel/certs
    mkdir /etc/mstunnel/private
    touch /etc/mstunnel/EulaAccepted

    # put the certs in place
    cp /etc/pki/tls/certs/letsencrypt.pem /etc/mstunnel/certs/site.crt
    cp /etc/pki/tls/private/letsencrypt.key /etc/mstunnel/private/site.key

    # Install
    ./mstunnel-setup
}

###########################################################################################
#                                                                                         #
#                                          Main()                                         #
#                                                                                         #
###########################################################################################

. vars

while getopts "hrip" options
do
    case "${options}" in
        h)
            Help
            ;;
        r)
            Uninstall
            exit
            ;;
        i)
            InstallPrereqs        
            ;;
        p)
            INSTALL_PROXY=1
            ;;
    esac
done

# setup server name
VerifyEnvironmentVars
ReplaceNames

if [[ !$SKIP_CERT_GENERATION ]]; then
    ConfigureCerts
    ./exportCert.sh
fi

InstallTunnelAppliance

BuildAndRunWebService
ConfigureNginx
ConfigureUnbound

if [[ $INSTALL_PROXY ]]; then
    BuildAndRunProxy
    PrintConf
fi