#!/bin/bash

echo "Trusted Root Cert as PEM:"

cat /etc/pki/tunnel/certs/cacert.pem

cp /etc/pki/tunnel/certs/cacert.pem ~/tunnelca.pem

echo ""
echo "Cert copied to ~/cacert.pem"
