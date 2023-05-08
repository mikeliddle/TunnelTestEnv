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
    sudo apt-get -y update >> install.log 2>&1
    sudo apt-get install -y squid >> install.log 2>&1
    
    if [ $? -ne 0 ]; then
        LogError "Failed to install prerequisites."
        exit 1
    fi
    
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
    
    if [ $? -ne 0 ]; then
        LogError "Failed to configure Squid."
        exit 1
    fi

    sudo systemctl restart squid
    LogInfo "Squid configured."
}

InstallPrereqs
ConfigureSquid