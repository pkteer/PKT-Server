#!/bin/bash
# Script to build and run docker container
# and print out the VPN exit info
echo "Building docker image support_server..."
docker build -t support_server .
echo "Please enter your secret key:"
read secret
echo "Running docker container support_server..."
docker run --cap-add=NET_ADMIN -d -p 47512:47512/udp -p 8099:8099 -e PKTEER_SECRET=$secret --name support_server support_server

docker exec support_server /bin/bash /server/vpn_info.sh
