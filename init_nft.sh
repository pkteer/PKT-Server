#!/bin/sh
adduser --no-create-home --disabled-password --disabled-login cjdns
adduser --no-create-home --disabled-password --disabled-login speedtest

## Switch the firewall
nft -f ./pfi.nft

ip rule add fwmark 0xfc table cjdns
ip rule add fwmark 0xcf table nocjdns

tc qdisc add dev tun0 root handle 1:0 hfsc default ffff
    tc class add dev tun0 parent 1:0 classid 1:1 hfsc ls m2 100mbit ul m2 100mbit
    tc class add dev tun0 parent 1:0 classid 1:2 hfsc ls m2 100mbit # speedtest, no upper limit O_O