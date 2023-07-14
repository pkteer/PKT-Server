#!/bin/bash
CJDNS_PORT=$(cat /home/d/PKT-Server/data/env/port)
IPERF_PORT=5281

docker run -it --rm \
           --log-driver 'local' \
           --cap-add=NET_ADMIN \
           --device /dev/net/tun:/dev/net/tun \
           --sysctl net.ipv6.conf.all.disable_ipv6=0 \
           --sysctl net.ipv4.ip_forward=1 \
           -p $CJDNS_PORT:$CJDNS_PORT \
           -p $CJDNS_PORT:$CJDNS_PORT/udp \
           -p $IPERF_PORT:$IPERF_PORT \
           -p $IPERF_PORT:$IPERF_PORT/udp \
           -v $(pwd)/data:/data \
           --name pkt-server \
           pkt-server
           