#!/bin/bash

LogInfo() {
    echo -e "\e[0;36m$1\e[0m"
}

LogError() {
    echo -e "\e[0;31m$1\e[0m"
}

LogWarning() {
    echo -e "\e[0;33m$1\e[0m"
}

Usage() {
    echo "Usage: $0 "
    echo "Example: $0 -a -p 10.0.0.5 "
    echo "Options:"
    echo "  -a: setup both webapps and nginx server"
    echo "  -w: setup webapps"
    echo "  -n: setup nginx server"
    echo "  -p: proxy ip address"
    echo "  -h: Show this help message"
    exit 1
}

SetupPrereqs() {
    LogInfo "Detecting OS"

    if [ -f "/etc/debian_version" ]; then
        installer="apt-get"
        update_command="apt-get update"
        ctr_cli="docker"
        ctr_package_name="docker.io"
        network_name="bridge"
    else
        installer="yum"
        update_command="yum update"
        ctr_cli="podman"
        ctr_package_name="@container-tools"
        network_name="podman"

        # need to allow 443 inbound for webservers to do HTTPS.
        firewall-cmd --zone=public --add-port=443/tcp
        firewall-cmd --zone=public --permanent --add-port=443/tcp
    fi

    $ctr_cli --version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        LogInfo "Installing prerequisites"
        $update_command >> install.log 2>&1
        $installer install -y $ctr_package_name >> install.log 2>&1

        if [ $? -ne 0 ]; then
            LogError "Failed to install $ctr_cli"
            exit 1
        fi
    fi

    if [ ! -f ./letsencrypt.pem ]; then
        LogError "missing letsencrypt certificate"
        exit 1
    fi

    if [ ! -f ./letsencrypt.key ]; then
        LogError "missing letsencrypt key"
        exit 1
    fi
}

SetupNginx() {
    LogInfo "Setting up private web server container"
    # create volume
    $ctr_cli volume create nginx-vol > nginx.log

    mv nginx.conf.d/nginx.conf.tmp nginx.conf.d/nginx.conf
    mv nginx_data/tunnel.pac.tmp nginx_data/tunnel.pac

	# run the containers on the $ctr_cli subnet
	$ctr_cli run -d \
        -p 443:443 \
        -p 80:80 \
        --mount type=volume,source=nginx-vol,dst=/etc/volume \
		--name=nginx \
		--restart=unless-stopped \
		docker.io/library/nginx >> nginx.log 2>&1

    NGINX_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" nginx)
    sed -i "s/##NGINX_IP##/${NGINX_IP}/g" *.d/*.conf

    $ctr_cli cp nginx.conf.d/nginx.conf nginx:/etc/nginx/nginx.conf
    $ctr_cli cp nginx_data/ nginx:/etc/volume/
    $ctr_cli cp /etc/pki/tls/certs/ nginx:/etc/volume/
    $ctr_cli cp /etc/pki/tls/private/ nginx:/etc/volume/
    $ctr_cli cp /etc/pki/tls/private/user.pfx nginx:/etc/volume/nginx_data/user.pfx

    $ctr_cli restart nginx >> nginx.log 2>&1

    NGINX_HEALTH=$($ctr_cli container inspect -f "{{ .State.Status }}" nginx)
    if [ "$NGINX_HEALTH" != "running" ]; then
        LogError "Failed to setup web server container"
        exit 1
    fi
}

SetupWebApps() {
    LogInfo "Setting up .NET web service"

    $ctr_cli image pull mliddle2/tunnelwebapp > webService.log

    $ctr_cli run -d \
        --name=webapp \
        --restart=unless-stopped \
        -p 8081:80 \
        -p 8443:443 \
        -p 3080:3080 \
        -p 3443:3443 \
        -e PROXY_IP=$PROXY_IP \
        -e ASPNETCORE_URLS="https://+;http://+" \
        -e ASPNETCORE_HTTPS_PORT=443 \
        -e ASPNETCORE_Kestrel__Certificates__Default__Password="" \
        -e ASPNETCORE_Kestrel__Certificates__Default__Path=/https/server.pfx \
        -v /etc/pki/tls/private:/https/ \
        mliddle2/tunnelwebapp >> webService.log 2>&1

    WEBSERVICE_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" webapp)
    sed -i "s/##WEBSERVICE_IP##/${WEBSERVICE_IP}/g" *.d/*.conf
    sed -i "s/##EXCLUDED_IP##/${WEBSERVICE_IP}/g" *.d/*.conf

    $ctr_cli cp fuzzing/fuzzing.js webapp:/fuzzing.js

    WEBSERVICE_HEALTH=$($ctr_cli container inspect -f "{{ .State.Status }}" webapp)
    if [ "$WEBSERVICE_HEALTH" != "running" ]; then
        LogError "Failed to setup .NET server container"
        exit 1
    fi
}

SetupAcmesh() {
    cp ./letsencrypt.pem /etc/pki/tls/certs/letsencrypt.pem  >> certs.log 2>&1
    cp ./letsencrypt.key /etc/pki/tls/private/letsencrypt.key  >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup LetsEncrypt cert"
        exit 1
    fi
}

while getopts ":awnp:e:" opt; do
    case $opt in
        a)
            WebApps=true
            Nginx=true
            ;;
        w)
            WebApps=true
            ;;
        n)
            Nginx=true
            ;;
        p)
            PROXY_IP=$OPTARG
            ;;
        h)
            Usage
            exit 0
            ;;
        \?)
            Usage
            exit 1
            ;;
        :)
            LogError "Option -$OPTARG requires an argument."
            exit 1
            ;;
    esac
done

SetupPrereqs

if [ "$Nginx" = true ]; then
    SetupAcmesh
    SetupNginx
fi

if [ "$WebApps" = true ]; then
    SetupWebApps
fi