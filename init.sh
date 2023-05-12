#!/bin/bash
# Set up iptables rules
echo "Cjdns port is: "
echo $(cat /server/cjdns/cjdroute.conf | grep bind | awk '/"0\.0\.0\.0:/' | cut -d':' -f3 | cut -d'"' -f1)
echo "Checking PKTEER_SECRET: $PKTEER_SECRET"
echo "Generating seed..."
echo "/server/cjdns/cjdroute.conf|$PKTEER_SECRET" | sha256sum | /server/cjdns/cjdroute --genconf-seed
echo "Setting up iptables rules"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1264
echo "Starting cjdns..."
sed -i 's/"setuser": "nobody"/"setuser": 0/' /server/cjdns/cjdroute.conf
/server/cjdns/cjdroute < /server/cjdns/cjdroute.conf
echo "route add..."
route add -net 10.66.0.0/16 tun0
echo "Starting anodevpn-server..."
node /server/anodevpn-server/index.js &
