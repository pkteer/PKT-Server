#!/bin/sh

die() {
        echo "Error: $1"
        exit 100
}
command -v jq > /dev/null || die "jq is required to run this program"
command -v dirname > /dev/null || die "dirname is required to run this program"
command -v docker > /dev/null || die "docker is required to run this program"
cd $(dirname "$0")

CJDNS_PORT=$(cat cjdroute.conf | jq -r '.interfaces.UDPInterface[0].bind' | sed 's/^.*://')
if [ -z "$CJDNS_PORT" ]; then
        echo "cjdroute not clean, trying to extract cjdns port"
        CJDNS_PORT=$(grep -A 5 "\"UDPInterface\"" cjdroute.conf | grep -oP '"bind": "\K[^"]+' | cut -d ':' -f2)
fi
echo "Cjdns Port: $CJDNS_PORT"
cjdns_rpc_port=""
cjdns_rpc=$(cat config.json | jq -r '.cjdns.expose_rpc')
pktd_lnd=$(cat config.json | jq -r '.pktd.lnd')
pktd=$(cat config.json | jq -r '.pktd.enabled')
vpn_flag=$(cat config.json | jq -r '.cjdns.vpn_exit')
speedtest=$(cat config.json | jq -r '.speedtest.enabled')
lnd_port=$(grep -A 1 "On all ipv4 interfaces on port 9735 and ipv6 localhost port 9736:" ./pktwallet/lnd/lnd.conf | grep "listen=" | cut -d ":" -f2)
# check if cjdns_rpc is not false
if [ "$cjdns_rpc" != "false" ]; then
        cjdns_rpc_port=$(cat cjdroute.conf | jq -r '.admin.bind' | cut -d ':' -f2)
        if [ "$cjdns_rpc_port" = true ]; then
                cjdns_rpc_port=$(grep -A 5 "\"admin\":" cjdroute.conf | grep -oP '"bind": "\K[^"]+' | cut -d ':' -f2)
        fi
        cat cjdroute.conf | jq '.admin.bind = "0.0.0.0:11234"' cjdroute.conf > cjdroute.tmp
        mv cjdroute.tmp cjdroute.conf
        echo "Exposing cjdns rpc port: $cjdns_rpc_port"
fi

docker run -it --rm \
        --log-driver 'local' \
        --cap-add=NET_ADMIN \
        --device /dev/net/tun:/dev/net/tun \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
        --sysctl net.ipv4.ip_forward=1 \
        $([ "$vpn_flag" = true ] && echo "-p 8099:8099") \
        -p $CJDNS_PORT:$CJDNS_PORT/udp \
        $([ "$speedtest" = true ] && echo "-p 5201:5201") \
        $([ "$speedtest" = true ] && echo "-p 5201:5201/udp") \
        $([ "$pktd" = true ] && echo "-p 64764:64764") \
        $([ "$pktd_lnd" = true ] && echo "-p $lnd_port:$lnd_port") \
        $([ "$cjdns_rpc_port" = true ] && echo "-p 127.0.0.1:$cjdns_rpc_port:$cjdns_rpc_port/udp") \
        -v $(pwd):/data \
        --name pkt-server-lnd \
        pkteer/pkt-server-lnd