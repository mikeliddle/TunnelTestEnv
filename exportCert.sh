#!/bin/bash

echo "Trusted Root Cert as PEM:"

cat /etc/pki/tls/cacert.pem

cp /etc/pki/tls/cacert.pem ~/cacert.pem

echo ""
echo "Cert copied to ~/cacert.pem"
