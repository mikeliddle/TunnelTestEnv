#!/bin/bash

echo "Trusted Root Cert as PEM:"

cat /etc/pki/tls/certs/cacert.pem
openssl x509 -in /etc/pki/tls/certs/cacert.pem -out /etc/pki/tls/certs/cacert.cer -outform DER

cp /etc/pki/tls/certs/cacert.pem ~/cacert.pem
cp /etc/pki/tls/certs/cacert.pem /home/azureuser/cacert.pem
cp /etc/pki/tls/certs/cacert.cer ~/cacert.cer

echo ""
echo "Cert copied to ~/cacert.pem"
echo "DER cert copied to ~/cacert.cer"
