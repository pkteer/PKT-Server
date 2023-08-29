#!/bin/sh

die() {
        echo "Error: $1"
        exit 100
}
command -v dirname || die "missing dirname"
cd $(dirname "$0")
CJDNS_PORT=$(cat cjdroute.conf | jq -r '.interfaces.UDPInterface[0].bind' | sed 's/^.*://')
if [ -z "$CJDNS_PORT" ]; then
        echo "cjdroute not clean, trying to extract cjdns port"
        CJDNS_PORT=$(grep -A 5 "\"UDPInterface\"" cjdroute.conf | grep -oP '"bind": "\K[^"]+' | cut -d ':' -f2)
fi
echo "Cjdns Port: $CJDNS_PORT"
cjdns_rpc=$(echo "$json_config" | jq -r '.cjdns.expose_rpc')
# check if cjdns_rpc is not false
if [ "$cjdns_rpc" != "false" ]; then
        cjdns_rpc_port=$(cat cjdroute.conf | jq -r '.admin.bind' | cut -d ':' -f2)
        if [ -z "$cjdns_rpc_port" ]; then
                cjdns_rpc_port=$(grep -A 5 "\"admin\":" cjdroute.conf | grep -oP '"bind": "\K[^"]+' | cut -d ':' -f2)
        fi        
        echo "Exposing cjdns rpc port: $cjdns_rpc_port"
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
        -p $cjdns_rpc_port:$cjdns_rpc_port/udp \
        -v $(pwd):/data \
        pkteer/pkt-server
else
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
fi