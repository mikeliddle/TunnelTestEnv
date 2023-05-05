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
<<<<<<< HEAD
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
    
=======
    sudo apt-get update
    sudo apt-get install -y squid
>>>>>>> 28c56ca (moved proxy configuration to use separate VM)
    LogInfo "Prerequisites installed."
}

Uninstall() {
    LogInfo "Uninstalling..."
<<<<<<< HEAD
    sudo apt-get remove -y squid >> install.log 2>&1
=======
    sudo apt-get remove -y squid
>>>>>>> 28c56ca (moved proxy configuration to use separate VM)
    LogInfo "Uninstalled."
}

ConfigureSquid() {
<<<<<<< HEAD
    cp ./squid.conf.tmp /etc/squid/squid.conf
    cp ./allowlist.tmp /etc/squid/allowlist
    
    if [ $? -ne 0 ]; then
        LogError "Failed to configure Squid."
        exit 1
    fi

=======
    cp ./squid.conf /etc/squid/squid.conf
    cp ./allowlist /etc/squid/allowlist
>>>>>>> 28c56ca (moved proxy configuration to use separate VM)
    sudo systemctl restart squid
    LogInfo "Squid configured."
}

InstallPrereqs
ConfigureSquid