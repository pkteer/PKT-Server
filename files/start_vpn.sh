#!/bin/sh

die() {
        echo "Error: $1"
        exit 100
}
command -v dirname || die "missing dirname"
cd $(dirname "$0")
CJDNS_PORT=$(cat ./env/port || die "cat ./env/port")
docker run -it --rm \
        --log-driver 'local' \
        --cap-add=NET_ADMIN \
        --device /dev/net/tun:/dev/net/tun \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
        --sysctl net.ipv4.ip_forward=1 \
        -p $CJDNS_PORT:$CJDNS_PORT \
        -p $CJDNS_PORT:$CJDNS_PORT/udp \
        -p 5281:5281 \
        -p 5281:5281/udp \
        -v $(pwd):/data \
        dimitris2023/pkt-server