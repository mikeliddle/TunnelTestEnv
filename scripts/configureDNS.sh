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
    echo "  none: setup unbound in a container"
    echo "  -u: Update an existing A record"
    echo "  -i: IP address to use for A record"
    echo "  -d: Domain name to use for A record"
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

        LogInfo "disabling resolved.service"
        sed -i "s/#DNS=/DNS=1.1.1.1/g" /etc/systemd/resolved.conf
        sed -i "s/#DNSStubListener=yes/DNSStubListener=no/g" /etc/systemd/resolved.conf
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
        systemctl stop systemd-resolved
    else
        installer="yum"
        update_command="yum update"
        ctr_cli="podman"
        ctr_package_name="@container-tools"

        # need to allow 443 inbound for webservers to do HTTPS.
        firewall-cmd --zone=public --add-port=53/tcp
        firewall-cmd --zone=public --add-port=53/udp
        firewall-cmd --zone=public --permanent --add-port=53/tcp
        firewall-cmd --zone=public --permanent --add-port=53/udp
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
}

AddARecord() {
    template='# local-data: "##DOMAIN##. A ##IP##"'
    ptr_template='# local-data-ptr: "##IP## ##DOMAIN##."'

    if [ -z "$DOMAIN_NAME" ]; then
        LogError "Missing domain name"
        exit 1
    fi

    if [ -z "$IP_ADDRESS" ]; then
        LogError "Missing IP address"
        exit 1
    fi

    UNBOUND_HEALTH=$($ctr_cli container inspect -f "{{ .State.Status }}" unbound)
    if [ "$UNBOUND_HEALTH" != "running" ]; then
        LogError "No DNS server running"
        exit 1
    fi

    record="$(echo $template | sed -e "s/##DOMAIN##/$DOMAIN_NAME/" -e "s/##IP##/$IP_ADDRESS/")"
    record="$record\n$template"
    ptr_record="$(echo $ptr_template | sed -e "s/##DOMAIN##/$DOMAIN_NAME/" -e "s/##IP##/$IP_ADDRESS/")"
    prt_record="$ptr_record\n$ptr_template"

    sed -i "s/$template/$record/" a-records.conf
    sed -i "s/$ptr_template/$ptr_record/" a-records.conf

    $ctr_cli cp a-records.conf unbound:/opt/unbound/etc/unbound/a-records.conf
    $ctr_cli restart unbound >> unbound.log 2>&1
}

SetupUnbound() {
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
    $ctr_cli cp a-records.conf unbound:/opt/unbound/etc/unbound/a-records.conf
    $ctr_cli cp unbound.conf unbound:/opt/unbound/etc/unbound/unbound.conf
    # restart to apply config change
    $ctr_cli restart unbound >> unbound.log 2>&1

    UNBOUND_HEALTH=$($ctr_cli container inspect -f "{{ .State.Status }}" unbound)
    if [ "$UNBOUND_HEALTH" != "running" ]; then
        LogError "Failed to setup DNS server container"
        exit 1
    fi
}

while getopts ":hud:i:" opt; do
    case $opt in
        u)
            Update=true
            ;;
        i)
            IP_ADDRESS=$OPTARG
            ;;
        d)
            DOMAIN_NAME=$OPTARG
            ;;
        h)
            Usage
            exit 1
            ;;
        \?)
            Usage
            exit 1
            ;;
    esac
done

SetupPrereqs

if [ $Update ]; then
    AddARecord
else
    SetupUnbound
fi
