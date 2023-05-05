#!/bin/bash
# Script to run docker container
# and print out the VPN exit info

echo "Please enter your secret key:"
read secret
echo "Provide a name for your VPN Exit"
echo "VPN Name: "
read name
echo "Country of VPN Exit: "
read country
echo "Enter your pkt.chat username in order to get direct notifications about changes to your VPN Server:"
read username

echo "Running docker container PKT-Server..."
docker run -d --rm \
        --log-driver 'local' \
        --cap-add=NET_ADMIN \
        --device /dev/net/tun:/dev/net/tun \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
        --sysctl net.ipv4.ip_forward=1 \
        -p $ANODE_SERVER_PORT:$ANODE_SERVER_PORT \
        -p $ANODE_SERVER_PORT:$ANODE_SERVER_PORT/udp \
        -e "PKTEER_SECRET=$secret" \
        -e "PKTEER_NAME=$name" \
        -e "PKTEER_COUNTRY=$country" \
        -e "PKTEER_CHAT_USERNAME=$username" \
        --name pkt-server pkt-server

docker exec -e "PKTEER_SECRET=$secret" pkt-server /server/init.sh
docker exec -e "PKTEER_NAME=$name" -e "PKTEER_COUNTRY=$country" pkt-server /server/vpn_info.sh
