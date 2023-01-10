#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $DIR/vars

TUNNEL_CLIENT_SUBNET=$(cat /etc/mstunnel/ocserv.conf | grep ipv4-network | cut -d = -f 2 | sed -e 's/\s*//')
if [ -z "$TUNNEL_CLIENT_SUBNET" ]; then
    echo "Microsoft Tunnel Server is not installed or not configured with default values."
    exit -1
fi

if [ -d $WD ]; then
    rm -rf $WD
fi

mkdir $WD
cp -rf $DIR/* $WD/

DIR=$WD

PROXY_BYPASS_NAME_TEMPLATE=$(cat $DIR/proxy/proxy_bypass_name_tamplate)

# DNS server
docker run \
        -d \
        --name $BIND_NAME \
        --restart always \
        --publish 53:53/udp \
        --publish 53:53/tcp \
        --volume /etc/bind \
        --volume /var/cache/bind \
        --volume /var/lib/bind \
        --volume /var/log \
        --network $TUNNEL_SERVER_NETWORK_NAME \
        internetsystemsconsortium/bind9:9.16
        #--cap-add=NET_ADMIN \
BIND9_IP=$(docker container inspect -f "{{ .NetworkSettings.Networks.$TUNNEL_SERVER_NETWORK_NAME.IPAddress }}" $BIND_NAME)

# Resource server
sed -i -e "s/\bPROXY_HOST_NAME\b/$PROXY_HOST_NAME/g" $DIR/resource/usr/share/nginx/html/tunnel.pac
sed -i -e "s/\bPROXY_PORT\b/$PROXY_PORT/g" $DIR/resource/usr/share/nginx/html/tunnel.pac
for pan in "${PROXY_BYPASS_NAMES[@]}"; do
    panline=$(echo $PROXY_BYPASS_NAME_TEMPLATE | sed -e "s/\bPROXY_BYPASS_NAME\b/$pan/g")
    sed -i -e "s#// PROXY_BYPASS_NAMES#$panline#g" $DIR/resource/usr/share/nginx/html/tunnel.pac;
done
docker run \
        -d \
        --name $RESOURCE_NAME \
        --restart always \
        --volume $DIR/resource/usr/share/nginx/html:/usr/share/nginx/html:ro \
        --dns "$BIND9_IP" \
        --network $TUNNEL_SERVER_NETWORK_NAME \
        nginx:latest
RESOURCE_IP=$(docker container inspect -f "{{ .NetworkSettings.Networks.$TUNNEL_SERVER_NETWORK_NAME.IPAddress }}" $RESOURCE_NAME)

# Proxy server
sed -i -e "s#\bTUNNEL_CLIENT_SUBNET\b#$TUNNEL_CLIENT_SUBNET#g" $DIR/proxy/etc/squid/squid.conf
sed -i -e "s/\bPROXY_PORT\b/$PROXY_PORT/g" $DIR/proxy/etc/squid/squid.conf
for pan in "${PROXY_ALLOWED_NAMES[@]}"; do
    echo "$pan" >> $DIR/proxy/etc/squid/allowlist
done
docker build . --build-arg PROXY_PORT=$PROXY_PORT --tag $PROXY_DOCKER_TAG --file $DIR/proxy/Dockerfile 
docker run \
        -d \
        --name $PROXY_NAME \
        --restart always \
        --volume /etc/squid \
        --dns "$BIND9_IP" \
        --dns-search "$DNS_SEARCH" \
        --network $TUNNEL_SERVER_NETWORK_NAME \
        $PROXY_DOCKER_TAG
PROXY_IP=$(docker container inspect -f "{{ .NetworkSettings.Networks.$TUNNEL_SERVER_NETWORK_NAME.IPAddress }}" $PROXY_NAME)

# DNS zone config
TUNNEL_SERVER_SUBNET=$(docker network inspect -f '{{json .IPAM.Config}}' $TUNNEL_SERVER_NETWORK_NAME | jq -r .[].Subnet)
TUNNEL_SERVER_SUBNET_ADDR=$(echo $TUNNEL_SERVER_SUBNET | cut -d / -f 1)
SUBNET_ADDRESS="$TUNNEL_SERVER_SUBNET_ADDR"
SUBNET="$TUNNEL_SERVER_SUBNET"
REVERSE_SUBNET=$(echo $SUBNET_ADDRESS | awk -F. 'OFS="." { print $3, $2, $1 }')
BIND9_IP_OCTET=$(echo $BIND9_IP | awk -F. 'OFS="." { print $4 }')
RESOURCE_IP_OCTET=$(echo $RESOURCE_IP | awk -F. 'OFS="." { print $4 }')
PROXY_IP_OCTET=$(echo $PROXY_IP | awk -F. 'OFS="." { print $4 }')


# named.conf
sed -i -e "s/\bZONE_NAME\b/$ZONE_NAME/g" $DIR/bind9/etc/bind/named.conf
sed -i -e "s/\bBIND9_IP\b/$BIND9_IP/g" $DIR/bind9/etc/bind/named.conf

sed -i -e "s#\bSUBNET\b#$SUBNET#g" $DIR/bind9/etc/bind/named.conf
sed -i -e "s#\REVERSE_SUBNET\b#$REVERSE_SUBNET#g" $DIR/bind9/etc/bind/named.conf
sed -i -e "s#\bTUNNEL_CLIENT_SUBNET\b#$TUNNEL_CLIENT_SUBNET#g" $DIR/bind9/etc/bind/named.conf

# Forward zone
sed -i -e "s/\bBIND9_IP\b/$BIND9_IP/g" $DIR/bind9/var/lib/bind/forward.resource.db
sed -i -e "s/\bRESOURCE_IP\b/$RESOURCE_IP/g" $DIR/bind9/var/lib/bind/forward.resource.db
sed -i -e "s/\bRESOURCE_ALIAS\b/$RESOURCE_ALIAS/g" $DIR/bind9/var/lib/bind/forward.resource.db
sed -i -e "s/\bPROXY_IP\b/$PROXY_IP/g" $DIR/bind9/var/lib/bind/forward.resource.db
sed -i -e "s/\bPROXY_NAME\b/$PROXY_NAME/g" $DIR/bind9/var/lib/bind/forward.resource.db
sed -i -e "s/\bZONE_NAME\b/$ZONE_NAME/g" $DIR/bind9/var/lib/bind/forward.resource.db

# Reverse zone
sed -i -e "s/\bBIND9_IP_OCTET\b/$BIND9_IP_OCTET/g" $DIR/bind9/var/lib/bind/reverse.resource.db
sed -i -e "s/\bRESOURCE_IP_OCTET\b/$RESOURCE_IP_OCTET/g" $DIR/bind9/var/lib/bind/reverse.resource.db
sed -i -e "s/\bRESOURCE_ALIAS\b/$RESOURCE_ALIAS/g" $DIR/bind9/var/lib/bind/reverse.resource.db
sed -i -e "s/\bPROXY_IP_OCTET\b/$PROXY_IP_OCTET/g" $DIR/bind9/var/lib/bind/reverse.resource.db
sed -i -e "s/\bPROXY_NAME\b/$PROXY_NAME/g" $DIR/bind9/var/lib/bind/reverse.resource.db
sed -i -e "s/\bZONE_NAME\b/$ZONE_NAME/g" $DIR/bind9/var/lib/bind/reverse.resource.db

# Copy bind9 files
docker cp $DIR/bind9/etc/bind/named.conf $BIND_NAME:/etc/bind/named.conf
docker cp $DIR/bind9/var/lib/bind/forward.resource.db $BIND_NAME:/var/lib/bind/forward.resource.db
docker cp $DIR/bind9/var/lib/bind/reverse.resource.db $BIND_NAME:/var/lib/bind/reverse.resource.db
docker restart $BIND_NAME
# docker logs bind9 -f

# Copy resource files
docker cp $DIR/resource/etc/nginx/mime.types $RESOURCE_NAME:/etc/nginx/mime.types
docker restart $RESOURCE_NAME
# docker logs contoso -f

# Copy proxy files
docker cp $DIR/proxy/etc/squid/squid.conf $PROXY_NAME:/etc/squid/squid.conf
docker cp $DIR/proxy/etc/squid/allowlist $PROXY_NAME:/etc/squid/allowlist
docker restart $PROXY_NAME
# docker logs proxy -f

echo "=================== Use the following to configure Microsoft Tunnel Server ======================="
echo "DNS server: $BIND9_IP"
echo "Private network route: $SUBNET"
echo "DNS suffix search: $DNS_SEARCH"
echo "Resource names: http://$RESOURCE_IP http://$RESOURCE_HOST_NAME http://$ZONE_NAME"
echo "Proxy server names: $PROXY_IP $PROXY_HOST_NAME"
echo "Proxy server port: $PROXY_PORT"
echo "PAC URL: http://$ZONE_NAME/tunnel.pac"
echo "Proxy bypassed names: ${PROXY_BYPASS_NAMES[*]}"
echo "Proxy allowed names: ${PROXY_ALLOWED_NAMES[*]}"
echo "=================================================================================================="
