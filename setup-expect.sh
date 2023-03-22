#!/bin/bash
. vars

if [ -f "/etc/debian_version" ]; then
    # debian
    installer="apt-get"
else
    # RHEL
    installer="dnf"
fi

sed -i "s/##SITE_ID##/${SITE_ID}/g" setup.exp
sed -i "s/##ARGS##/${SETUP_ARGS}/g" setup.exp

$installer -y update
$installer install -y expect