#!/bin/bash
# Script to build and run docker container
# and print out the VPN exit info
echo "Building docker image PKT-Server..."
docker build -t pkt-server .
echo "Please enter your secret key:"
read secret
echo "Running docker container PKT-Server..."
docker run --cap-add=NET_ADMIN -d -p 47512:47512/udp -p 8099:8099 -e PKTEER_SECRET=$secret --name pkt-server pkt-server

docker exec pkt-server /bin/bash /server/vpn_info.sh
