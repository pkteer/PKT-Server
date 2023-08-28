#!/bin/sh

die() {
        echo "Error: $1"
        exit 100
}
command -v dirname || die "missing dirname"
cd $(dirname "$0")
CJDNS_PORT=$(cat cjdroute.conf | jq -r '.interfaces.UDPInterface[0].bind' | sed 's/^.*://')
docker run -it --rm \
        --log-driver 'local' \
        --cap-add=NET_ADMIN \
        --device /dev/net/tun:/dev/net/tun \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
        --sysctl net.ipv4.ip_forward=1 \
        -p 8099:8099 \
        -p $CJDNS_PORT:$CJDNS_PORT/udp \
        -p 5281:5281 \
        -p 5281:5281/udp \
        -p 64764:64764 \
        -v $(pwd):/data \
        pkteer/pkt-server