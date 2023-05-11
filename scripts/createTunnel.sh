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
        firewall-cmd --zone=public --add-port=443/udp
        firewall-cmd --zone=public --permanent --add-port=443/tcp
        firewall-cmd --zone=public --permanent --add-port=443/udp
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

    # make the correct directories
    mkdir -p /etc/mstunnel
    mkdir -p /etc/mstunnel/certs
    mkdir -p /etc/mstunnel/private
    
    # Touch EULA
    touch /etc/mstunnel/EulaAccepted

    # recoverable, you'll need to interact though.
    cp agent-info.json /etc/mstunnel/agent-info.json > /dev/null 2>&1
    cp agent.p12 /etc/mstunnel/private/agent.p12 > /dev/null 2>&1
}

InstallTunnelAppliance() {
    # Copying certs into place
    if [ ! -f "$certfile" ]; then
        LogError "Cert file $certfile does not exist"
        exit 1
    fi
    
    if [ ! -f "$keyfile" ]; then
        LogError "Key file $keyfile does not exist"
        exit 1
    fi

    cp $certfile /etc/mstunnel/certs/site.crt
    cp $keyfile /etc/mstunnel/private/site.key

    # Install
    LogInfo "Installing Tunnel"
    mst_no_prompt=1 ./mstunnel-setup

    if [ $? -ne 0 ]; then
        LogError "Failed to install Tunnel"
        exit 1
    fi
}

while getopts ":hc:k:" opt; do
    case ${opt} in
        c)
            certfile=$OPTARG
            ;;
        k)
            keyfile=$OPTARG
            ;;
        h )
            Usage
            exit 1
            ;;
        \? )
            Usage
            exit 1
            ;;
    esac
done

SetupPrereqs
InstallTunnelAppliance
