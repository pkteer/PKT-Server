#!/bin/bash
# Set up iptables rules
echo "Setting up iptables rules"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
echo "sysctl..."
sysctl -w net.ipv4.ip_forward=1
echo "Starting cjdns..."
/server/cjdns/cjdroute < /server/cjdns/cjdroute.conf
echo "route add..."
route add -net 10.66.0.0/16 tun0
echo "Starting anodevpn-server..."
node /server/anodevpn-server/index.js
