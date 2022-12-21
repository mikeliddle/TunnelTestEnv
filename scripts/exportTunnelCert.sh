#!/bin/bash

echo "Trusted Root Cert as PEM:"

cat /etc/pki/tunnel/certs/cacert.pem

cp /etc/pki/tunnel/certs/cacert.pem ~/cacert.pem

echo ""
echo "Cert copied to ~/cacert.pem"
