#!/bin/sh
## Switch the firewall
nft -f ./pfi.nft

UPPER_LIMIT_MBIT=$(cat /data/config.json | jq -r '.upper_limit_mbit')

tc qdisc replace dev tun0 root handle 1:0 hfsc default ffff
    tc class replace dev tun0 parent 1:0 classid 1:fffe hfsc ls m2 950mbit 
    tc class replace dev tun0 parent 1:0 classid 1:ffff hfsc ls m2 1mbit
        tc qdisc replace dev tun0 parent 1:ffff handle ffff: cake

tc qdisc add dev eth0 root handle 1:0 hfsc default fffe
  tc class add dev eth0 parent 1:0 classid 1:ffff hfsc ls m2 100mbit ul m2 ${UPPER_LIMIT_MBIT}mbit
    tc class add dev eth0 parent 1:ffff classid 1:fffe hfsc ls m2 100kbit # 1:fffe = management
      tc qdisc add dev eth0 parent 1:fffe handle fffe: cake
    tc class add dev eth0 parent 1:ffff classid 1:fffd hfsc ls m2 1kbit # 1:fffd = speedtest
    tc class add dev eth0 parent 1:ffff classid 1:fffc hfsc ls m2 100kbit # 1:fffc = cjdns