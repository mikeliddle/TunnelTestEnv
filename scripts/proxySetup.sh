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
    LogInfo "Installing prerequisites..."
    maxRetries=3
    retryCount=0
    installSucceeded=1
    sudo apt-get -y update >> install.log 2>&1

    while [ $installSucceeded -ne 0 ] && [ $retryCount -lt $maxRetries ]; do 
        sudo apt-get install -y squid >> install.log 2>&1
        
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
    
    LogInfo "Prerequisites installed."
}

InstallInspectionProxy() {
    LogInfo "Installing..."
    maxRetries=3
    retryCount=0
    installSucceeded=1

    wget -qO - https://packages.diladele.com/diladele_pub.asc | sudo apt-key add -
    echo "deb https://squid57.diladele.com/ubuntu/ focal main" > /etc/apt/sources.list.d/squid57.diladele.com.list
    apt update >> install.log 2>&1

    while [ $installSucceeded -ne 0 ] && [ $retryCount -lt $maxRetries ]; do 
        apt install y squid-common squid-openssl squidclient libecap3 libecap3-dev >> install.log 2>&1

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

Uninstall() {
    LogInfo "Uninstalling..."
    sudo apt-get remove -y squid >> install.log 2>&1
    LogInfo "Uninstalled."
}

ConfigureSquid() {
    cp ./squid.conf.tmp /etc/squid/squid.conf
    cp ./allowlist.tmp /etc/squid/allowlist
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

while getopts "bu" opt; do
    case $opt in
        b)
            InstallInspectionProxy
            ConfigureSquid
            exit 0
            ;;
        u)
            Uninstall
            exit 0
            ;;
        \?)
            LogError "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

InstallPrereqs
ConfigureSquid