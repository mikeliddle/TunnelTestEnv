#!/bin/bash
. vars

if [ -f "/etc/debian_version" ]; then
    # debian
    installer="apt-get"
else
    # RHEL
    installer="dnf"
fi

sed -i "s/##SITE_ID##/${SITE_ID}/g" scripts/setup.exp
sed -i "s/##ARGS##/${SETUP_ARGS}/g" scripts/setup.exp

$installer -y update >> install.log 2>&1
$installer install -y expect  >> install.log 2>&1