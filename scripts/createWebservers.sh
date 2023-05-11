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
    echo "Example: $0 "
    echo "Options:"
    echo "  -h: Show this help message"
    exit 1
}

SetupPrereqs() {
    LogInfo "Detecting OS"

    if [ -f "/etc/debian_version" ]; the
        installer="apt-get"
        update_command="apt-get update"
        ctr_cli="docker"
        ctr_package_name="docker.io"
    else
        installer="yum"
        update_command="yum update"
        ctr_cli="podman"
        ctr_package_name="@container-tools"

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

    if [ ! -d "acme.sh"]; then
        LogInfo "Installing acme.sh"
        curl https://get.acme.sh | sh >> install.log 2>&1

        if [ $? -ne 0 ]; then
            LogError "Failed to install acme.sh"
            exit 1
        fi
    fi
}

SetupNginx() {
    LogInfo "Setting up private web server container"
    # create volume
    $ctr_cli volume create nginx-vol > nginx.log

	# run the containers on the $ctr_cli subnet
	$ctr_cli run -d \
        -p 443:443 \
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
    current_dir=$(pwd)

    cd sampleWebService

    $ctr_cli build -t samplewebservice . > webService.log

    $ctr_cli run -d \
        --name=webApp \
        --restart=unless-stopped \
        -p 80:80 \
        -p 8443:443 \
        -e ASPNETCORE_URLS="https://+;http://+" \
        -e ASPNETCORE_HTTPS_PORT=443 \
        -e ASPNETCORE_Kestrel__Certificates__Default__Password="" \
        -e ASPNETCORE_Kestrel__Certificates__Default__Path=/https/server.pfx \
        -v /etc/pki/tls/private:/https/ \
        samplewebservice >> webService.log 2>&1

    $ctr_cli run -d \
        --name=excluded \
        --restart=unless-stopped \
        -p 8080:80 \
        -p 9443:443 \
        -e ASPNETCORE_URLS="https://+;http://+" \
        -e ASPNETCORE_HTTPS_PORT=443 \
        -e ASPNETCORE_Kestrel__Certificates__Default__Password="" \
        -e ASPNETCORE_Kestrel__Certificates__Default__Path=/https/server.pfx \
        -v /etc/pki/tls/private:/https/ \
        samplewebservice >> webService.log 2>&1

    cd $current_dir

    WEBSERVICE_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" webApp)
    sed -i "s/##WEBSERVICE_IP##/${WEBSERVICE_IP}/g" *.d/*.conf

    EXCLUDED_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" excluded)
    sed -i "s/##EXCLUDED_IP##/${EXCLUDED_IP}/g" *.d/*.conf

    WEBSERVICE_HEALTH=$($ctr_cli container inspect -f "{{ .State.Status }}" webApp)
    if [ "$WEBSERVICE_HEALTH" != "running" ]; then
        LogError "Failed to setup .NET server container"
        exit 1
    fi

    EXCLUDED_HEALTH=$($ctr_cli container inspect -f "{{ .State.Status }}" excluded)
    if [ "$EXCLUDED_HEALTH" != "running" ]; then
        LogError "Failed to setup .NET server container"
        exit 1
    fi
}

SetupAcmesh() {
    cd acme.sh
    
	./acme.sh --install -m $EMAIL >> install.log
	
    if [ $? -ne 0 ]; then
        LogError "acme.sh not properly setup... aborting"
        cd ..
        exit 1
    fi

    cd ..

    ~/.acme.sh/acme.sh --upgrade  >> certs.log 2>&1
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt  >> certs.log 2>&1
    ~/.acme.sh/acme.sh --register-account  >> certs.log 2>&1

    ~/.acme.sh/acme.sh --upgrade --update-account --accountemail $EMAIL  >> certs.log 2>&1

    ~/.acme.sh/acme.sh --issue --alpn -d $DOMAIN_NAME --preferred-chain "ISRG ROOT X1" --keylength 4096  >> certs.log 2>&1

    cp ~/.acme.sh/$DOMAIN_NAME/fullchain.cer certs/letsencrypt.pem  >> certs.log 2>&1
    cp ~/.acme.sh/$DOMAIN_NAME/$DOMAIN_NAME.key private/letsencrypt.key  >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup LetsEncrypt cert"
        exit 1
    fi
}

while getopts ":awnd:e:" opt; do
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
        d)
            DOMAIN_NAME=$OPTARG
            ;;
        e)
            EMAIL=$OPTARG
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
    if [ -z "$DOMAIN_NAME" ]; then
        LogError "Domain name is required"
        exit 1
    fi

    if [ -z "$EMAIL" ]; then
        LogError "Email is required"
        exit 1
    fi

    SetupAcmesh
    SetupNginx
fi

if [ "$WebApps" = true ]; then
    SetupWebApps
fi
