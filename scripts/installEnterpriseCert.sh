#!/bin/bash

if [[-d /etc/mstunnel]]; then
    TUNNEL_EXISTS=1
    echo "tunnel has already been installed"
else
    echo "preparing tunnel folder structure"
    mkdir /etc/mstunnel
    mkdir /etc/mstunnel/certs
    mkdir /etc/mstunnel/private
fi

echo "forming fullchain file"
cat /etc/pki/tunnel/certs/cacert.pem >> /etc/pki/tunnel/certs/server.pem

echo "moving certs to Tunnel directories"
cp /etc/pki/tunnel/certs/server.pem /etc/mstunnel/certs/active.crt
cp /etc/pki/tunnel/certs/server.pem /etc/mstunnel/certs/site.crt
cp /etc/pki/tunnel/private/server.key /etc/mstunnel/certs/site.key

if [[$TUNNEL_EXISTS]]; then
    echo "running mst-cli import_cert"
    mst-cli import_cert

    echo "restarting the tunnel server for new cert to take effect"
    mst-cli server restart
fi