#!/bin/sh
## Switch the firewall
nft -f ./pfi.nft

UPPER_LIMIT_MBIT=$(cat /data/config.json | jq -r '.upper_limit_mbit')
if [ -z "$UPPER_LIMIT_MBIT" ]
then
    UPPER_LIMIT_MBIT=1000 # 1Gbps default limit
fi
DEFAULT_INTERFACE=$(ip route | awk '/default/ { print $5 }')

tc qdisc add dev tun0 root handle 1:0 hfsc default ffff
    tc class add dev tun0 parent 1:0 classid 1:fffe hfsc ls m2 950mbit 
    tc class add dev tun0 parent 1:0 classid 1:ffff hfsc ls m2 1mbit
        tc qdisc add dev tun0 parent 1:ffff handle ffff: cake

tc qdisc add dev $DEFAULT_INTERFACE root handle 1:0 hfsc default fffe
  tc class add dev $DEFAULT_INTERFACE parent 1:0 classid 1:ffff hfsc ls m2 100mbit ul m2 ${UPPER_LIMIT_MBIT}mbit
    tc class add dev $DEFAULT_INTERFACE parent 1:ffff classid 1:fffe hfsc ls m2 100kbit # 1:fffe = management
      tc qdisc add dev $DEFAULT_INTERFACE parent 1:fffe handle fffe: cake
    tc class add dev $DEFAULT_INTERFACE parent 1:ffff classid 1:fffd hfsc ls m2 1kbit # 1:fffd = speedtest
    tc class add dev $DEFAULT_INTERFACE parent 1:ffff classid 1:fffc hfsc ls m2 100kbit # 1:fffc = cjdns