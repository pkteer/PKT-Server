#!/bin/bash
echo "Provide the port to use for cjdns default (8099):"
read CJDNS_PORT
echo "Provide the secret to use for cjdns:"
read PKTEER_SECRET

echo "Running docker container cjdns..."
docker run -d -it \
        --log-driver 'local' \
        --cap-add=NET_ADMIN \
        --device /dev/net/tun:/dev/net/tun \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
        --sysctl net.ipv4.ip_forward=1 \
        -p $CJDNS_PORT:$CJDNS_PORT \
        -p $CJDNS_PORT:$CJDNS_PORT/udp \
        -e "PKTEER_CJDNS_PORT=$CJDNS_PORT" \
        -e "PKTEER_SECRET=$PKTEER_SECRET" \
        --name cjdns cjdns

docker exec cjdns /server/init_cjdns.sh
