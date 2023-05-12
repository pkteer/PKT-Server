#!/bin/sh
## Switch the firewall
nft -f ./pfi.nft

tc qdisc add dev tun0 root handle 1:0 hfsc default ffff
    tc class add dev tun0 parent 1:0 classid 1:1 hfsc ls m2 100mbit m2 100mbit
    tc class add dev tun0 parent 1:0 classid 1:2 hfsc ls m2 100kbit ul m2 100kbit
        tc qdisc add dev tun0 parent 1:2 handle 2: cake
    tc class add dev tun0 parent 1:0 classid 1:3 hfsc ls m2 100mbit # speedtest, no upper limit O_O