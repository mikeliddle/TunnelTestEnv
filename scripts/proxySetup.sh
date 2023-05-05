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
    sudo apt-get update
    sudo apt-get install -y squid
    LogInfo "Prerequisites installed."
}

Uninstall() {
    LogInfo "Uninstalling..."
    sudo apt-get remove -y squid
    LogInfo "Uninstalled."
}

ConfigureSquid() {
    cp ./squid.conf /etc/squid/squid.conf
    cp ./allowlist /etc/squid/allowlist
    sudo systemctl restart squid
    LogInfo "Squid configured."
}

InstallPrereqs
ConfigureSquid