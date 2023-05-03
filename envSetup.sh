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

InstallPrereqs() {
    LogInfo "installing container runtime"
    $update_command >> install.log 2>&1
    $installer install -y $ctr_package_name >> install.log 2>&1
    $installer install -y jq >> install.log 2>&1

    $ctr_cli --version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        LogError "Missing container runtime... aborting"
        exit 1
    fi

    LogInfo "disabling resolved.service"
    sed -i "s/#DNS=/DNS=1.1.1.1/g" /etc/systemd/resolved.conf
    sed -i "s/#DNSStubListener=yes/DNSStubListener=no/g" /etc/systemd/resolved.conf
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    systemctl stop systemd-resolved

    LogInfo "pulling mst-readiness and mstunnel-setup"
    wget -q aka.ms/mst-readiness 
    [ $? -ne 0 ] && exit
    chmod +x mst-readiness

    wget -q --output-document=mstunnel-setup https://aka.ms/microsofttunneldownload
    [ $? -ne 0 ] && exit
    chmod +x ./mstunnel-setup


    LogInfo "setting up acme.sh"
    git submodule update --init
	cd acme.sh
    
	./acme.sh --install -m $EMAIL >> install.log
	
    if [ $? -ne 0 ]; then
        LogError "acme.sh not properly setup... aborting"
        exit 1
    fi

	cd ..
}

Help() {
    echo "Usage: sudo ./envSetup.sh [options]"
    echo "  -i : install pre-reqs before configuring and setting up the environment"
    echo "  -r : remove the configuration. Doesn't uninstall pre-reqs or undo steps to disable systemd-resolved"
    echo "  -p : install and configure a squid proxy"
    echo "  -e : configure the tunnel appliance to use the enterprise CA for it's TLS cert"
    echo "  -u : redeploy proxy, webservers, and dns servers"
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
    LogInfo "removing $ctr_cli containers"
	$ctr_cli stop nginx
	$ctr_cli rm nginx

    $ctr_cli stop unbound
    $ctr_cli rm unbound

    $ctr_cli stop webService
    $ctr_cli rm webService

    $ctr_cli stop proxy
    $ctr_cli rm proxy

    LogInfo "removing $ctr_cli volumes"
    $ctr_cli volume rm nginx-vol
    $ctr_cli volume rm unbound

    LogInfo "uninstalling tunnel"
    mst-cli uninstall

    git reset --hard
    git pull --recurse-submodules # Needed to reset acme.sh
    chmod +x envSetup.sh exportCert.sh 
}

VerifyEnvironmentVars() {
    if [ -z $SERVER_NAME ]; then
        LogError "MISSING SERVER NAME... Aborting."
        fail=1
    fi
    if [ -z $DOMAIN_NAME ]; then
        LogError "MISSING DOMAIN NAME... Aborting."
        fail=1
    fi
    if [ -z $SERVER_PUBLIC_IP ]; then
        LogError "MISSING PUBLIC IP... Aborting."
        fail=1
    fi
    if [ -z $EMAIL ]; then
        LogError "MISSING EMAIL... Aborting."
        fail=1
    fi
    if [ -z $PROXY_ALLOWED_NAMES ]; then
        LogWarning "MISSING PROXY ALLOWED NAMES, no urls will be allowed through the proxy."
    fi
    if [ -z $PROXY_BYPASS_NAMES ]; then
        LogWarning "MISSING PROXY BYPASS NAMES, all urls will have to go through the proxy."
    fi
    if [ $fail ]; then
        exit 1
    fi
}

ReplaceNames() {
    LogInfo "Injecting Environment variables"

    sed -i "s/##SERVER_NAME##/${SERVER_NAME}/g" *.d/*.conf
    sed -i "s/##DOMAIN_NAME##/${DOMAIN_NAME}/g" *.d/*.conf
    sed -i "s/##SERVER_PUBLIC_IP##/${SERVER_PUBLIC_IP}/g" *.d/*.conf
    sed -i "s/##DOMAIN_NAME##/${DOMAIN_NAME}/g" proxy/squid.conf
}

###########################################################################################
#                                                                                         #
#                           Simple Env Setup with $ctr_cli                                  #
#                                                                                         #
###########################################################################################

ConfigureCerts() {
    LogInfo "configuring certs"
    # push current directory
    current_dir=$(pwd)

    # setup PKI folder structure
    mkdir -p /etc/pki/tls
    mkdir -p /etc/pki/tls/certs
    mkdir -p /etc/pki/tls/req
    mkdir -p /etc/pki/tls/private

    touch /etc/pki/tls/index.txt
    
    if [ $? -ne 0 ]; then
        LogError "Failed to setup pki directory structure"
        exit 1
    fi
    
    # copy config into the tls folder structure
    cp openssl.conf.d/* /etc/pki/tls

    cd /etc/pki/tls

    # generate self-signed root CA
    openssl genrsa -out private/cakey.pem 4096 >> certs.log 2>&1
    openssl req -new -x509 -days 3650 -extensions v3_ca -config cacert.conf -key private/cakey.pem \
        -out certs/cacert.pem >> certs.log 2>&1
    openssl pkcs12 -export -out private/cacert.pfx -inkey private/cakey.pem -in certs/cacert.pem -passout pass: >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup CA cert"
        exit 1
    fi

    openssl genrsa -out private/intermediatekey.pem 4096 >> certs.log 2>&1
    openssl req -new -key private/intermediatekey.pem -out req/intermediate.csr -config intermediate.conf >> certs.log 2>&1
    openssl ca -in req/intermediate.csr -out certs/intermediate.pem -config intermediate.conf -batch >> certs.log 2>&1

    # generate leaf from our CA
    openssl genrsa -out private/server.key 4096 >> certs.log 2>&1
    openssl req -new -key private/server.key -out req/server.csr -config openssl.conf >> certs.log 2>&1
    openssl x509 -req -days 365 -in req/server.csr -CA certs/intermediate.pem -CAkey private/intermediatekey.pem \
        -CAcreateserial -out certs/server.pem -extensions req_ext -extfile openssl.conf >> certs.log 2>&1
    openssl pkcs12 -export -out private/server.pfx -inkey private/server.key -in certs/server.pem -passout pass: >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup Leaf cert"
        exit 1
    fi

    # generate user cert from our CA
    openssl genrsa -out private/user.key 4096 >> certs.log 2>&1
    openssl req -new -key private/user.key -out req/user.csr -config user.conf >> certs.log 2>&1
    openssl x509 -req -days 365 -in req/user.csr -CA certs/intermediate.pem -CAkey private/intermediatekey.pem \
        -CAcreateserial -out certs/user.pem -extensions req_ext -extfile user.conf >> certs.log 2>&1
    openssl pkcs12 -export -out private/user.pfx -inkey private/user.key -in certs/user.pem -passout pass: >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup User cert"
        exit 1
    fi

    # generate untrusted leaf cert
    openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -config untrusted.conf -nodes -out \
        certs/untrusted.pem -keyout private/untrusted.key >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup Self-Signed cert"
        exit 1
    fi

    if [[ !$SKIP_LETS_ENCRYPT ]]; then
		/root/.acme.sh/acme.sh --upgrade  >> certs.log 2>&1
		/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt  >> certs.log 2>&1
		/root/.acme.sh/acme.sh --register-account  >> certs.log 2>&1

		/root/.acme.sh/acme.sh --upgrade --update-account --accountemail $EMAIL  >> certs.log 2>&1

		/root/.acme.sh/acme.sh --issue --alpn -d $DOMAIN_NAME --preferred-chain "ISRG ROOT X1" --keylength 4096  >> certs.log 2>&1

		cp /root/.acme.sh/$DOMAIN_NAME/fullchain.cer certs/letsencrypt.pem  >> certs.log 2>&1
		cp /root/.acme.sh/$DOMAIN_NAME/$DOMAIN_NAME.key private/letsencrypt.key  >> certs.log 2>&1

        if [ $? -ne 0 ]; then
            LogError "Failed to setup LetsEncrypt cert"
            exit 1
        fi
    fi

    cd $current_dir
    # pop current directory
}

ConfigureUnbound() {
    LogInfo "Setting up private DNS server"
    # create the unbound volume
    $ctr_cli volume create unbound > unbound.log

    # run the unbound container
    $ctr_cli run -d \
        --name=unbound \
        -v unbound:/opt/unbound/etc/unbound/ \
        -p 53:53/tcp \
        -p 53:53/udp \
        --restart=unless-stopped \
        docker.io/mvance/unbound:latest >> unbound.log 2>&1

    # copy in necessary config files
    $ctr_cli cp unbound.conf.d/a-records.conf unbound:/opt/unbound/etc/unbound/a-records.conf
    $ctr_cli cp unbound.conf.d/unbound.conf unbound:/opt/unbound/etc/unbound/unbound.conf
    # restart to apply config change
    $ctr_cli restart unbound >> unbound.log 2>&1

    UNBOUND_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" unbound)

    UNBOUND_HEALTH=$($ctr_cli container inspect -f "{{ .State.Status }}" unbound)
    if [ "$UNBOUND_HEALTH" != "running" ]; then
        LogError "Failed to setup DNS server container"
        exit 1
    fi
}

ConfigureNginx() {
    LogInfo "Setting up private web server container"
    # create volume
    $ctr_cli volume create nginx-vol > nginx.log

	# run the containers on the $ctr_cli subnet
	$ctr_cli run -d \
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

###########################################################################################
#                                                                                         #
#                             Simple Squid Proxy Setup                                    #
#                                                                                         #
###########################################################################################

BuildAndRunProxy() {
    LogInfo "Setting up squid proxy container"

    PROXY_BYPASS_NAME_TEMPLATE=$(cat proxy/proxy_bypass_name_template)
    UNBOUND_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" unbound)

    sed -i -e "s/\bPROXY_HOST_NAME\b/proxy.$DOMAIN_NAME/g" nginx_data/tunnel.pac
    sed -i -e "s/\bPROXY_PORT\b/3128/g" nginx_data/tunnel.pac

    for pan in "${PROXY_BYPASS_NAMES[@]}"; do
        LogInfo "Proxy bypass name: $pan"
        panline=$(echo $PROXY_BYPASS_NAME_TEMPLATE | sed -e "s/PROXY_BYPASS_NAME/$pan/")
        sed -i -e "s#// PROXY_BYPASS_NAMES#$panline#g" nginx_data/tunnel.pac;
    done

    for name in "${PROXY_ALLOWED_NAMES[@]}"; do
        LogInfo "Proxy allowed name: $name"
        echo $name >> proxy/allowlist
    done

    $ctr_cli run -d \
            --name proxy \
            -p 3128 \
            --restart always \
            --volume /etc/squid \
            -v $(pwd)/proxy/squid.conf:/etc/squid/squid.conf \
            --dns "$UNBOUND_IP" \
            --dns-search "$DOMAIN_NAME" \
            ubuntu/squid >> proxy.log 2>&1

    PROXY_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" proxy)
    sed -i "s/##PROXY_IP##/${PROXY_IP}/g" *.d/*.conf
    sed -i "s/PROXY_URL/proxy.${DOMAIN_NAME}/g" nginx_data/tunnel.pac
    
    # $ctr_cli copy into nginx container
    $ctr_cli cp nginx_data/tunnel.pac nginx:/etc/volume/nginx_data/tunnel.pac
    sed -i "s/# local-data/local-data/g" unbound.conf.d/a-records.conf
    $ctr_cli cp unbound.conf.d/a-records.conf unbound:/opt/unbound/etc/unbound/a-records.conf
    $ctr_cli restart unbound >> proxy.log 2>&1

    $ctr_cli cp $(pwd)/proxy/allowlist proxy:/etc/squid/allowlist >> proxy.log 2>&1
    $ctr_cli restart proxy >> proxy.log 2>&1

    PROXY_HEALTH=$($ctr_cli container inspect -f "{{ .State.Status }}" proxy)
    if [ "$PROXY_HEALTH" != "running" ]; then
        LogError "Failed to setup proxy container"
        exit 1
    fi
}

PrintConf() {
    echo -e "\e[0;32m=================== Use the following to configure Microsoft Tunnel Server ======================="
    echo "DNS server: $UNBOUND_IP"

    if [[ $INSTALL_PROXY ]]; then
        echo "Proxy server names: $PROXY_IP proxy.$DOMAIN_NAME"
        echo "Proxy server port: 3128"
        echo "PAC URL: http://$DOMAIN_NAME/tunnel.pac"
        echo "Proxy bypassed names: ${PROXY_BYPASS_NAMES[*]}"
        echo "Proxy allowed names: ${PROXY_ALLOWED_NAMES[*]}"
    fi

    echo "Configured endpoints behind firewall:"
    echo "  https://${DOMAIN_NAME}"
    echo "  https://trusted.${DOMAIN_NAME}"
    echo "  https://untrusted.${DOMAIN_NAME}"
    echo "  https://webapp.${DOMAIN_NAME}"
    echo "  https://excluded.${DOMAIN_NAME}"
    echo "  http://${DOMAIN_NAME}"
    echo -e "==================================================================================================\e[0m"
}

###########################################################################################
#                                                                                         #
#                                    JS SPA env setup                                     #
#                                                                                         #
###########################################################################################

BuildAndRunWebService() {
    LogInfo "Setting up .NET web service"
    current_dir=$(pwd)

    cd sampleWebService

    $ctr_cli build -t samplewebservice . > webService.log

    $ctr_cli run -d \
        --name=webApp \
        --restart=unless-stopped \
        -p 80 \
        -p 443 \
        -e ASPNETCORE_URLS="https://+;http://+" \
        -e ASPNETCORE_HTTPS_PORT=443 \
        -e ASPNETCORE_Kestrel__Certificates__Default__Password="" \
        -e ASPNETCORE_Kestrel__Certificates__Default__Path=/https/server.pfx \
        -v /etc/pki/tls/private:/https/ \
        samplewebservice >> webService.log 2>&1

    $ctr_cli run -d \
        --name=excluded \
        --restart=unless-stopped \
        -p 80 \
        -p 443 \
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

###########################################################################################
#                                                                                         #
#                              Install Tunnel Appliance                                   #
#                                                                                         #
###########################################################################################
InstallTunnelAppliance() {
    # Install
    LogInfo "Installing Tunnel"
    mst_no_prompt=1 ./mstunnel-setup

    if [ $? -ne 0 ]; then
        LogError "Failed to install Tunnel"
        exit 1
    fi
}

SetupTunnelPrereqs() {
    # make the correct directories
    mkdir -p /etc/mstunnel
    mkdir -p /etc/mstunnel/certs
    mkdir -p /etc/mstunnel/private
    
    # Touch EULA
    touch /etc/mstunnel/EulaAccepted

    # recoverable, you'll need to interact though.
    cp agent-info.json /etc/mstunnel/agent-info.json > /dev/null 2>&1
}

###########################################################################################
#                                                                                         #
#                                  Update Tunnel Certs                                    #
#                                                                                         #
###########################################################################################
SetupEnterpriseCerts() {
    # put the certs in place
    # no need using a different server cert, just need to reformat it.
    cp /etc/pki/tls/certs/server.pem /etc/pki/tls/certs/tunnel.pem
    
    if [ $? -ne 0 ]; then
        LogError "Failed to setup leaf cert"
        exit 1
    fi

    cat /etc/pki/tls/certs/cacert.pem >> /etc/pki/tls/certs/tunnel.pem

    cp /etc/pki/tls/certs/tunnel.pem /etc/mstunnel/certs/site.crt    
    cp /etc/pki/tls/private/server.key /etc/mstunnel/private/site.key

    if [ $? -ne 0 ]; then
        LogError "Failed to setup certs"
        exit 1
    fi

    LogWarning "Make sure this root certificate is uploaded to Intune and targeted properly"
}

SetupTunnelCerts() {
    # put the certs in place
    cp /etc/pki/tls/certs/letsencrypt.pem /etc/mstunnel/certs/site.crt
    if [ $? -ne 0 ]; then
        LogError "Failed to setup LetsEncrypt certs"
        exit 1
    fi

    cp /etc/pki/tls/private/letsencrypt.key /etc/mstunnel/private/site.key
    
    if [ $? -ne 0 ]; then
        LogError "Failed to setup LetsEncrypt certs"
        exit 1
    fi

    # recoverable by tunnel, don't bail here.
    cp agent.p12 /etc/mstunnel/private/agent.p12 > /dev/null 2>&1
}

###########################################################################################
#                                                                                         #
#                                          Update                                         #
#                                                                                         #
###########################################################################################
Update(){
    # capture initial state
    NGINX_INITIAL_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" nginx)
    WEBAPP_INITIAL_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" webService)
    PROXY_INITIAL_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" proxy)
    UNBOUND_INITIAL_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" unbound)
    UNBOUND_IP="$UNBOUND_INITIAL_IP"
    
    # start with nginx
    $ctr_cli stop nginx
    $ctr_cli rm nginx
    $ctr_cli volume rm nginx-vol

    WEBSERVICE_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" webService)
    sed -i "s/##WEBSERVICE_IP##/${WEBSERVICE_IP}/g" *.d/*.conf
    
    ConfigureNginx

    NGINX_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" nginx)
    if [ "${NGINX_INITIAL_IP}" != "${NGINX_IP}" ]; then
        LogWarning "NGINX IP has changed from $NGINX_INITIAL_IP to $NGINX_IP"
    fi

    # Next do the webapp
    $ctr_cli stop webService
    $ctr_cli rm webService

    BuildAndRunWebService

    WEBAPP_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" webService)
    if [ "${WEBAPP_INITIAL_IP}" != "${WEBAPP_IP}" ]; then
        LogWarning "Simple Web App IP has changed from $WEBAPP_INITIAL_IP to $WEBAPP_IP"
    fi

    # next the proxy?
    PROXY_ENABLED=$($ctr_cli container ls | grep proxy)
    if [ "${PROXY_ENABLED}" ]; then
        $ctr_cli stop proxy
        $ctr_cli rm proxy

        BuildAndRunProxy

        PROXY_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" proxy)
        if [ "${PROXY_INITIAL_IP}" != "${PROXY_IP}" ]; then
            LogWarning "Proxy IP has changed from $PROXY_INITIAL_IP to $PROXY_IP, make sure to update your VPN profile to reflect this."
        fi
    fi

    # Last, unbound
    $ctr_cli stop unbound
    $ctr_cli rm unbound
    $ctr_cli volume rm unbound

    ConfigureUnbound

    UNBOUND_IP=$($ctr_cli container inspect -f "{{ .NetworkSettings.Networks.$network_name.IPAddress }}" unbound)
    if [ "$UNBOUND_INITIAL_IP" != "$UNBOUND_IP" ]; then
        LogWarning "DNS Server IP has changed from $UNBOUND_INITIAL_IP to $UNBOUND_IP, make sure to update your Tunnel Server Configuration to reflect this."
    fi
}

DetectEnvironment() {
    . vars

    if [ -f "/etc/debian_version" ]; then
        # debian
        ctr_cli="docker"
        installer="apt-get"
        update_command="apt-get update"
        ctr_package_name="docker.io"
        network_name="bridge"
    else
        # RHEL
        ctr_cli="podman"
        installer="dnf"
        update_command="dnf -y update"
        ctr_package_name="@container-tools"
        network_name="podman"
        # open up port 443
        firewall-cmd --zone=public --add-port=443/tcp
        firewall-cmd --zone=public --add-port=443/udp
        firewall-cmd --zone=public --permanent --add-port=443/tcp
        firewall-cmd --zone=public --permanent --add-port=443/udp
    fi
}

###########################################################################################
#                                                                                         #
#                                          Main()                                         #
#                                                                                         #
###########################################################################################
DetectEnvironment

while getopts "hripeu" options
do
    case "${options}" in
        h)
            Help
	        exit
            ;;
        r)
            Uninstall
            exit
            ;;
        i)
            InstallPrereqs
            ;;
        e)
            ENTERPRISE_CA=1
            ;;
        p)
            INSTALL_PROXY=1
            ;;
        u)
            VerifyEnvironmentVars
            ReplaceNames
            Update
            exit
            ;;
        ?)
            Help
	        exit
            ;;
    esac
done

# setup server name
VerifyEnvironmentVars
ReplaceNames
SetupTunnelPrereqs

if [[ !$SKIP_CERT_GENERATION ]]; then
    ConfigureCerts
    ./exportCert.sh  >> certs.log 2>&1
fi

if [[ $ENTERPRISE_CA ]]; then
    SetupEnterpriseCerts
else
    SetupTunnelCerts
fi

InstallTunnelAppliance

BuildAndRunWebService
ConfigureNginx
ConfigureUnbound

if [[ $INSTALL_PROXY ]]; then
    BuildAndRunProxy
    PrintConf
fi
