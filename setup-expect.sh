#!/bin/bash
. vars

if [ -f "/etc/debian_version" ]; then
    # debian
    installer="apt-get"
elif [ -f "/etc/centos-release" ]; then
    # centos
    installer="yum"
else
    # RHEL
    installer="dnf"
fi

sed -i "s/##SITE_ID##/${SITE_ID}/g" setup.exp
sed -i "s/##ARGS##/${SETUP_ARGS}/g" setup.exp

$installer -y update >> install.log 2>&1
$installer install -y expect  >> install.log 2>&1