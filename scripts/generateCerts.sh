#!/bin/bash

ConfigureCerts() {
    # push current directory
    current_dir=$(pwd)

    # setup PKI folder structure
    mkdir $PKI_ROOT
    mkdir $PKI_ROOT/certs
    mkdir $PKI_ROOT/req
    mkdir $PKI_ROOT/private
    
    # copy config into the tls folder structure
    cp openssl.conf.d/* $PKI_ROOT

    cd $PKI_ROOT

    # generate self-signed root CA
    openssl genrsa -out private/cakey.pem 4096
    openssl req -new -x509 -days 3650 -extensions v3_ca -config cacert.conf -key private/cakey.pem \
        -out certs/cacert.pem 

    # generate leaf from our CA
    openssl genrsa -out private/server.key 4096
    openssl req -new -key private/server.key -out req/server.csr -config openssl.conf
    openssl x509 -req -days 365 -in req/server.csr -CA certs/cacert.pem -CAkey private/cakey.pem \
        -CAcreateserial -out certs/server.pem -extensions req_ext -extfile openssl.conf

    # generate untrusted leaf cert
    openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -config untrusted.conf -nodes -out \
        certs/untrusted.pem -keyout private/untrusted.key

    if [[ !$SKIP_LETS_ENCRYPT ]]; then
        certbot certonly --standalone -d $DOMAIN_NAME

        cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem certs/letsencrypt.pem
        cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem private/letsencrypt.key

        openssl pkcs12 -export -out private/letsencrypt.pfx -inkey private/letsencrypt.key \
            -in certs/letsencrypt.pem -nodes -password pass:
    fi

    cd $current_dir
    # pop current directory
}

if [ -z $PKI_ROOT ]; then
    PKI_ROOT=/etc/pki/tls
fi