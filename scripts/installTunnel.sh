#!/bin/bash

echo "downloading readiness script"
wget --output-document=mst-readiness https://aka.ms/microsofttunnelready
chmod +x mst-readiness
./mst-readiness network

if [[$? == 0]]; then
    echo "downloading mstunnel-setup"
    wget --output-document=mstunnel-setup https://aka.ms/microsofttunneldownload
    chmod +x mstunnel-setup

    ./scripts/installEnterpriseCert.sh

    ./mstunnel-setup
else
    echo "readiness script failed" >&2
    exit 2
fi