#!/bin/bash

echo "Trusted Root Cert as PEM:"

cat /etc/pki/tls/certs/cacert.pem

cp /etc/pki/tls/certs/cacert.pem ~/cacert.pem

echo ""
echo "Cert copied to ~/cacert.pem"
