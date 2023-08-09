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
    echo "  -b: setup TLS inspection on the proxy"
    echo "  -u: uninstall proxy"
    echo "  -h: Show this help message"
    exit 1
}

InstallPrereqs() {
    LogInfo "Installing prerequisites..."
    maxRetries=3
    sudo apt-get -y update >> install.log 2>&1

    for command in "sudo apt-get install -y squid" "sudo apt-get install -y apache2-utils";
    do
        LogInfo "Preparing command '$command'..."
        retryCount=0
        installSucceeded=1
        while [ $installSucceeded -ne 0 ] && [ $retryCount -lt $maxRetries ]; do 
            LogInfo "Running command '$command'..."
            $command >> install.log 2>&1
            
            if [ $? -ne 0 ]; then
                LogError "Failed to install prerequisites."
                installSucceeded=1
                retryCount=$((retryCount+1))
                sleep 5
            else
                LogInfo "Succeeded in running command '$command'"
                installSucceeded=0
                break
            fi
        done

        if [ $installSucceeded -ne 0 ]; then
            LogError "Failed to install prerequisites after $maxRetries attempts."
            exit 1
        fi
    done

    LogInfo "Prerequisites installed."
}

InstallInspectionProxy() {
    LogInfo "Installing..."
    maxRetries=3
    retryCount=0
    installSucceeded=1

    mkdir -p /etc/apt/keyrings
    wget -q https://packages.diladele.com/diladele_pub.asc 
    cp diladele_pub.asc /etc/apt/keyrings/diladele_pub.asc
    echo "deb [signed-by=/etc/apt/keyrings/diladele_pub.asc] https://squid57.diladele.com/ubuntu/ focal main" > /etc/apt/sources.list.d/squid57.diladele.com.list
    apt update >> install.log 2>&1

    while [ $installSucceeded -ne 0 ] && [ $retryCount -lt $maxRetries ]; do 
        apt install -y squid-common squid-openssl squidclient libecap3 libecap3-dev >> install.log 2>&1

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

    if [ $installSucceeded -ne 0 ]; then
        LogError "Failed to install prerequisites after $maxRetries attempts."
        exit 1
    fi
    
    /usr/lib/squid/security_file_certgen -c -s /etc/squid/ssl_db -M 10

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
    cp ./passwords /etc/squid/passwords
    LogInfo "Prepared Basic Authentication..."
}

Uninstall() {
    LogInfo "Uninstalling..."
    sudo apt-get remove -y squid >> install.log 2>&1
    LogInfo "Uninstalled."
}

ConfigureSquid() {
    cp ./squid.conf /etc/squid/squid.conf
    cp ./allowlist /etc/squid/allowlist
    cp ./ssl_error_domains /etc/squid/ssl_error_domains
    cp ./ssl_exclude_domains /etc/squid/ssl_exclude_domains
    cp ./ssl_exclude_ips /etc/squid/ssl_exclude_ips
    
    if [ $? -ne 0 ]; then
        LogError "Failed to configure Squid."
        exit 1
    fi

    sudo systemctl restart squid
    LogInfo "Squid configured."
}

while getopts "abu" opt; do
    case $opt in
        a)
            LogInfo "Configuring with basic authentication."
            InstallPrereqs
            PrepareBasicAuthentication
            ConfigureSquid
            exit 0
            ;;
        b)
            InstallInspectionProxy
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
ConfigureSquid