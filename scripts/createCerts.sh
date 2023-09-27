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
    echo "Usage: $0 -[risux] [-c <common name>] [-a <alt names>]"
    echo "Example: $0 -ris -c mydomain.com -a \"DNS.1:mydomain.com\nDNS.2:www.mydomain.com\""
    echo "Options:"
    echo "  -r: Create root certificate"
    echo "  -i: Create issuing certificate"
    echo "  -s: Create server certificate (requires -c and -a)"
    echo "  -u: Create user certificate"
    echo "  -x: Create a self-signed certificates"
    echo "  -c: Common name for certificate"
    echo "  -a: Alt names for certificate"
    echo "  -h: Show this help message"
    exit 1
}

SetupPrereqs() {
    LogInfo "Detecting OS"
    if [ -f "/etc/debian_version" ]; then
        installer="apt-get"
        update_command="apt-get update"
    else
        installer="yum"
        update_command="yum update"
    fi

    which openssl > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        LogInfo "Installing prerequisites"
        $update_command >> install.log 2>&1
        $installer install -y openssl >> install.log 2>&1
        if [ $? -ne 0 ]; then
            LogError "Failed to install openssl"
            exit 1
        fi
    fi

    LogInfo "Creating directories for certificates"
    mkdir -p /etc/pki/tls/certs
    mkdir -p /etc/pki/tls/req
    mkdir -p /etc/pki/tls/private

    touch /etc/pki/tls/index.txt

    if [ $? -ne 0 ]; then
        LogError "Failed to create directories for certificates"
        exit 1
    fi

    cp openssl.conf.d/* /etc/pki/tls
}

CreateRootCert() {
    current_dir=$(pwd)
    cd /etc/pki/tls

    LogInfo "Creating root certificate"

    openssl genrsa -out private/cakey.pem 4096 >> certs.log 2>&1
    openssl req -new -x509 -days 3650 -extensions v3_ca -config cacert.conf -key private/cakey.pem \
        -out certs/cacert.pem >> certs.log 2>&1
    openssl pkcs12 -export -out private/cacert.pfx -inkey private/cakey.pem -in certs/cacert.pem -passout pass: >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup CA cert"
        cd $current_dir
        exit 1
    fi

    cd $current_dir
}

CreateIssuingCert() {
    current_dir=$(pwd)
    cd /etc/pki/tls

    LogInfo "Creating Issuing CA"

    openssl genrsa -out private/intermediatekey.pem 4096 >> certs.log 2>&1
    openssl req -new -key private/intermediatekey.pem -out req/intermediate.csr -config intermediate.conf >> certs.log 2>&1
    openssl ca -in req/intermediate.csr -out certs/intermediate.pem -config intermediate.conf -batch >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup Intermediate CA"
        cd $current_dir
        exit 1
    fi

    cd $current_dir
}

CreateServerCert() {
    current_dir=$(pwd)
    cd /etc/pki/tls

    LogInfo "Creating Server Certificate"

    # save unedited conf file
    cp openssl.conf openssl.conf.bak
    sed -i "s/##DOMAIN_NAME##/$1/g" openssl.conf
    sed -i "s/##ALT_NAMES##/$2/g" openssl.conf
    
    # generate leaf from our CA
    openssl genrsa -out private/server.key 4096 >> certs.log 2>&1
    openssl req -new -key private/server.key -out req/server.csr -config openssl.conf >> certs.log 2>&1
    openssl x509 -req -days 365 -in req/server.csr -CA certs/intermediate.pem -CAkey private/intermediatekey.pem \
        -CAcreateserial -out certs/server.pem -extensions req_ext -extfile openssl.conf >> certs.log 2>&1

    touch certs/serverchain.pem
    cat certs/intermediate.pem | sed -n "/-----BEGIN CERTIFICATE-----/,/t-----END CERTIFICATE-----/p" > certs/intermediate-trimmed.pem
    cat certs/server.pem certs/intermediate-trimmed.pem certs/cacert.pem > certs/serverchain.pem
    
    cp certs/serverchain.pem /home/azureuser/serverchain.pem
    cp private/server.key  /home/azureuser/server.key
    chmod 777 /home/azureuser/serverchain.pem
    chmod 777 /home/azureuser/server.key

    openssl pkcs12 -export -out private/server.pfx -inkey private/server.key -in certs/server.pem -certfile certs/serverchain.pem -passout pass: >> certs.log 2>&1
    
    if [ $? -ne 0 ]; then
        LogError "Failed to setup Leaf cert"
        cd $current_dir
        exit 1
    fi

    cp openssl.conf.bak openssl.conf
    cd $current_dir
}

CreateUserCert() {
    current_dir=$(pwd)
    cd /etc/pki/tls

    LogInfo "Creating User Certificate"
    # generate user cert from our CA
    openssl genrsa -out private/user.key 4096 >> certs.log 2>&1
    openssl req -new -key private/user.key -out req/user.csr -config user.conf >> certs.log 2>&1
    openssl x509 -req -days 365 -in req/user.csr -CA certs/intermediate.pem -CAkey private/intermediatekey.pem \
        -CAcreateserial -out certs/user.pem -extensions req_ext -extfile user.conf >> certs.log 2>&1
    openssl pkcs12 -export -out private/user.pfx -inkey private/user.key -in certs/user.pem -passout pass: >> certs.log 2>&1

    chmod 766 private/user.pfx

    if [ $? -ne 0 ]; then
        LogError "Failed to setup User cert"
        cd $current_dir
        exit 1
    fi

    cd $current_dir
}

CreateSelfSignedCert() {
    current_dir=$(pwd)
    cd /etc/pki/tls

    LogInfo "Creating Self-Signed Server Certificate"

    openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -config untrusted.conf -nodes -out \
        certs/untrusted.pem -keyout private/untrusted.key >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup Self-Signed cert"
        cd $current_dir
        exit 1
    fi

    cd $current_dir
}

while getopts ":rsuixc:a:" opt; do
    case $opt in
        r)
            RootCert=true
            ;;
        s)
            ServerCert=true
            ;;
        u)  
            UserCert=true
            ;;
        i)
            IssuingCert=true
            ;;
        x)
            SelfSignedCert=true
            ;;
        c)
            commonName="$OPTARG"
            ;;
        a)
            altNames="$OPTARG"
            ;;
        h)
            Usage
            exit 0
            ;;
        \?)
            Usage
            exit 1
            ;;
        :)
            LogError "Option -$OPTARG requires an argument."
            exit 1
            ;;
    esac
done

SetupPrereqs
if [[ $RootCert ]]; then
    CreateRootCert
fi
if [[ $IssuingCert ]]; then
    CreateIssuingCert
fi
if [[ $ServerCert ]]; then
    if [[ -z $commonName ]]; then
        LogError "Common name (-c) is required for server certificate"
        exit 1
    fi

    if [[ -z $altNames ]]; then
        LogError "Alt names (-a) are required for server certificate"
        exit 1
    fi

    CreateServerCert $commonName $altNames
fi
if [[ $UserCert ]]; then
    CreateUserCert
fi
if [[ $SelfSignedCert ]]; then
    CreateSelfSignedCert
fi