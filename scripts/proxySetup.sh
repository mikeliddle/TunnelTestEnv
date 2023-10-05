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
    echo "Usage: $0 -abu"
    echo "Example: $0"
    echo "Options:"
    echo "  -a: use an authenticated proxy"
    echo "  -u: uninstall proxy"
    echo "  -h: Show this help message"
    exit 1
}

InstallPrereqs() {
    LogInfo "Installing prerequisites..."
    maxRetries=3
    retryCount=0
    installSucceeded=1

    while [ $installSucceeded -ne 0 ] && [ $retryCount -lt $maxRetries ]; do 
    
    apt -y update \
    && apt -y install apache2-utils docker.io >> install.log 2>&1

        if [ $? -ne 0 ]; then
            LogError "Failed to install prerequisites."
            installSucceeded=1
            retryCount=$((retryCount+1))
            sleep 5
        else
            installSucceeded=0
            break
        fi
    done

    LogInfo "Prerequisites installed."
}

PrepareBasicAuthentication() {
    LogInfo "Preparing Basic Authentication..."
    touch hashedpasswords
    while IFS="" read -r line || [ -n "$line" ]
    do
        IFS=':' read -r username password <<< "$line"
        htpasswd -b hashedpasswords $username $password
    done < ./passwords
    rm ./passwords
    mv ./hashedpasswords ./passwords
    docker cp ./passwords proxy:/etc/squid/passwords
    LogInfo "Prepared Basic Authentication..."
}

Uninstall() {
    LogInfo "Uninstalling..."
    sudo apt-get remove -y squid >> install.log 2>&1
    LogInfo "Uninstalled."
}

ConfigureSquid() {
    docker cp ./squid.conf proxy:/etc/squid/squid.conf
    docker cp ./allowlist proxy:/etc/squid/allowlist
    docker cp ./ssl_error_domains proxy:/etc/squid/ssl_error_domains
    docker cp ./ssl_exclude_domains proxy:/etc/squid/ssl_exclude_domains
    docker cp ./ssl_exclude_ips proxy:/etc/squid/ssl_exclude_ips
    docker cp /etc/pki/tls/certs proxy:/etc/squid/certs
    docker cp /etc/pki/tls/private proxy:/etc/squid/private
    
    docker restart proxy >> squid.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to configure Squid."
        exit 1
    fi
    LogInfo "Squid configured."
}

StartSquid() {
    LogInfo "Setting up Squid proxy container"
    docker volume create squid-vol > squid.log

    docker run -d \
        -p 3128:3128 \
        --mount type=volume,source=squid-vol,dst=/etc/squid \
        --name=proxy \
        --restart=unless-stopped \
        mliddle2/tunnelproxy >> squid.log 2>&1
}

while getopts "au" opt; do
    case $opt in
        a)
            LogInfo "Configuring with basic authentication."
            InstallPrereqs
            StartSquid
            PrepareBasicAuthentication
            ConfigureSquid
            exit 0
            ;;
        u)
            Uninstall
            exit 0
            ;;
        h)
            Usage
            exit 0
            ;;
        \?)
            Usage
            exit 1
            ;;
    esac
done

InstallPrereqs
StartSquid
ConfigureSquid