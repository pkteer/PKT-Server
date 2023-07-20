#!/bin/sh
## Switch the firewall
nft -f ./pfi.nft

tc qdisc replace dev tun0 root handle 1:0 hfsc default ffff
    tc class replace dev tun0 parent 1:0 classid 1:fffe hfsc ls m2 950mbit 
    tc class replace dev tun0 parent 1:0 classid 1:ffff hfsc ls m2 1mbit
        tc qdisc replace dev tun0 parent 1:ffff handle ffff: cake