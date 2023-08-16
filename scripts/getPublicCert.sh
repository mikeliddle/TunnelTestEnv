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
    echo "Usage: $0 -e <email>"
    echo "Example: $0 -e user@example.com"
    echo "Options:"
    echo "  -d <domain>: Domain name to get certificate for"
    echo "  -e <email>: Email address used for LetsEncrypt registration"
    echo "  -h: Show this help message"
    exit 1
}

SetupPrereqs() {
    LogInfo "Detecting OS"

    if [ ! -d ./acme.sh ]; then
        LogInfo "Installing acme.sh"
        curl https://get.acme.sh | sh -s email=$EMAIL >> install.log 2>&1

        if [ $? -ne 0 ]; then
            LogError "Failed to install acme.sh"
            exit 1
        fi
    fi
}

SetupAcmesh() {
    current_dir=$(pwd)
    ~/.acme.sh/acme.sh --upgrade  >> certs.log 2>&1
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt  >> certs.log 2>&1
    ~/.acme.sh/acme.sh --register-account  >> certs.log 2>&1

    ~/.acme.sh/acme.sh --upgrade --update-account --accountemail $EMAIL  >> certs.log 2>&1

    ~/.acme.sh/acme.sh --issue --alpn -d $DOMAIN_NAME --preferred-chain "ISRG ROOT X1" --keylength 4096  >> certs.log 2>&1

    if [ $? -ne 0 ]; then
        LogError "Failed to setup LetsEncrypt cert"
        cd $current_dir
        exit 1
    fi

    cd $current_dir
}

CopyAndPrintCertificate() {
    LogInfo "Copying certificate to current directory"
    cp ~/.acme.sh/$DOMAIN_NAME/fullchain.cer ./letsencrypt.pem
    cp ~/.acme.sh/$DOMAIN_NAME/$DOMAIN_NAME.key ./letsencrypt.key
    chmod 777 ./letsencrypt.pem
    chmod 777 ./letsencrypt.key

    LogInfo "Printing certificate"
    cat ./letsencrypt.pem
}

while getopts ":e:d:" opt; do
    case $opt in
        d)
            DOMAIN_NAME=$OPTARG
            ;;
        e)
            EMAIL=$OPTARG
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

if [ -z "$EMAIL" ]; then
    LogError "Email address is required"
    exit 1
fi

if [ -z "$DOMAIN_NAME" ]; then
    LogError "Domain name is required"
    exit 1
fi

SetupPrereqs
SetupAcmesh
CopyAndPrintCertificate
