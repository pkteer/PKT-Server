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

echo "Starting container pkt-server..."

cjdns_rpc_port=""
cjdns_rpc=$(cat config.json | jq -r '.cjdns.expose_rpc')
region=$(cat config.json | jq -r '.region')
city=$(cat config.json | jq -r '.city')
if [ -z "$region" ] || [ -z "$city" ]; then
  echo "Region or city is empty. Set them at config.json."
  exit 1
fi
# check if cjdns_rpc is not false
if [ "$cjdns_rpc" != "false" ]; then
        cjdns_rpc_port=$(cat cjdroute.conf | jq -r '.admin.bind' | cut -d ':' -f2)
        if [ -n "$cjdns_rpc_port" ]; then
                cjdns_rpc_port=$(grep -A 5 "\"admin\":" cjdroute.conf | grep -oP '"bind": "\K[^"]+' | cut -d ':' -f2)
        fi
        cat cjdroute.conf | jq '.admin.bind = "0.0.0.0:11234"' cjdroute.conf > cjdroute.tmp
        mv cjdroute.tmp cjdroute.conf
        echo "Exposing cjdns rpc port: $cjdns_rpc_port"
fi
echo "With following timezone: $region/$city"
echo "Using the following ports: "
echo "          Cjdns: $CJDNS_PORT"
echo "          Cjdns rpc: $cjdns_rpc_port"
echo "          AnodeVPN server: 8099"
echo "          iperf (speedtest): 5201"
echo "          pktd node: 64764"
echo "          SNIProxy: 80, 443"
echo "          IKEv2 (VPN): 500, 4500"
echo "          OpenVPN (VPN): 943, 1194"
echo "-----------------------------------"
echo "To check logs run: docker logs -f pkt-server"
echo "To check status of services run: ./vpn_data/status.sh"
echo "To enter the container run: docker exec -it pkt-server bash"
echo "To stop the container run: docker stop pkt-server"

docker run -it --rm \
        -e TZ=$region/$city \
        --log-driver 'local' \
        --cap-add=NET_ADMIN \
        --device /dev/net/tun:/dev/net/tun \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
        --sysctl net.ipv6.conf.all.forwarding=1 \
        --sysctl net.ipv4.ip_forward=1 \
        -p 8099:8099 \
        -p $CJDNS_PORT:$CJDNS_PORT/udp \
        -p 5201:5201 \
        -p 5201:5201/udp \
        -p 64764:64764 \
        -p 443:443 \
        -p 80:80 \
        -p 500:500/udp \
        -p 4500:4500/udp \
        -p 943:943 \
        -p 1194:1194/udp \
        -v $(pwd)/openvpn:/etc/openvpn \
        -v $(pwd)/vpnclients:/server/vpnclients \
        $([ -n "$cjdns_rpc_port" ] && echo "-p 127.0.0.1:$cjdns_rpc_port:$cjdns_rpc_port/udp") \
        -v $(pwd):/data \
        -v ikev2-vpn-data:/etc/ipsec.d \
        -v /lib/modules:/lib/modules:ro \
        -d --privileged \
        --name pkt-server \
        pkteer/pkt-server
