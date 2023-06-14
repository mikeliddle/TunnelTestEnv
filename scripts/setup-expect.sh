#!/bin/bash

if [ -f "/etc/debian_version" ]; then
    # debian
    installer="apt-get"
else
    # RHEL
    installer="yum"
fi

$installer -y update >> install.log 2>&1
$installer install -y expect  >> install.log 2>&1