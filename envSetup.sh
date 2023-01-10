#!/bin/bash

InstallPrereqs() {
    echo "installing Docker"
    apt update > run.log 2>&1
    apt remove -y docker >>  run.log 2>&1
    apt install -y docker.io >> run.log 2>&1
    apt install -y jq >> run.log 2>&1

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
    echo "Before running, set the following environment variables:"
    echo "	export SERVER_NAME=example"
    echo "	export DOMAIN_NAME=example.com"
    echo "	export SERVER_PRIVATE_IP=10.x.x.x"
    echo "	export SERVER_PUBLIC_IP=20.x.x.x"
    echo ""
    echo "Optional"
    echo "  export SKIP_LETS_ENCRYPT=1 - to skip the letsencrypt automation steps"
    echo "  export SKIP_CERT_GENERATION=1 - to skip generating new PKI certs"
}

Uninstall() {
    echo "removing docker containers"
    docker stop untrusted
    docker rm untrusted
    
    docker stop trusted
    docker rm trusted
    
    docker stop letsencrypt
    docker rm letsencrypt
    
    docker stop unbound
    docker rm unbound

    docker stop simpleapp	
    docker rm simpleapp

    docker stop webService
    docker rm webService

    echo "removing docker volumes"
    docker volume rm nginx-vol
    docker volume rm unbound

    echo "removing /etc/pki/tls folder"
    rm -rf /etc/pki/tls
}

VerifyEnvironmentVars() {

    if [ -z $DOMAIN_NAME ]; then
    read -p "Enter the fqdn of the server : " DOMAIN_NAME
    fi

    if [ -z $SERVER_NAME ]; then
        read -p "Enter the hostname of the server : " SERVER_NAME
    fi

    if [ -z $SERVER_PRIVATE_IP ]; then
        read -p "Enter the private(local) IP address of the server : " SERVER_PRIVATE_IP
    fi

    if [ -z $SERVER_PUBLIC_IP ]; then
        read -p "Enter the public IP address of the server : " SERVER_PUBLIC_IP
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

    # run the container with multiple servers
    docker run -d \
        --name=nginx_rp \
        --mount source=nginx-vol,destination=/etc/volume \
        --restart=unless-stopped \
        -v /var/lib/docker/volumes/nginx-vol/_data/nginx.conf.d/trusted.conf:/etc/nginx/nginx.conf:ro \
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
        -p 8880:80 \
        -p 7443:7443 \
        -e ASPNETCORE_URLS="https://+;http://+" \
        -e ASPNETCORE_HTTPS_PORT=7443 \
        -e ASPNETCORE_Kestrel__Certificates__Default__Password="" \
        -e ASPNETCORE_Kestrel__Certificates__Default__Path=/https/letsencrypt.pfx \
        -v /etc/pki/tls/private/letsencrypt.pfx:/https/letsencrypt.pfx \
        samplewebservice

    cd $current_dir
}

###########################################################################################
#                                                                                         #
#                                    Cert Generation                                      #
#                                                                                         #
###########################################################################################

ConfigureCerts() {
    ./scripts/generateCerts.sh
    PKI_ROOT="/etc/pki/tunnel" && SKIP_LETS_ENCRYPT=1 ./scripts/generateCerts.sh 
}

###########################################################################################
#                                                                                         #
#                                          Main()                                         #
#                                                                                         #
###########################################################################################

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