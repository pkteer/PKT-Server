#!/bin/bash

dockername="pkt-server"

# hostname
hostname=$(cat config.json | jq -r '.hostname')

# Initialize an empty JSON object
json_output=$(jq -n '{}')

json_output=$(jq --arg hostname "$hostname" '. + {hostname: $hostname}' <<<"$json_output")

# PKT wallet
json_output=$(jq '. + {"pktwallet": 0}' <<<"$json_output")
pld=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl pld | awk '{print $1}')
if [ -n "$pld" ]; then
    json_output=$(jq --argjson pld "$pld" '.pktwallet = $pld' <<<"$json_output")
fi

# CJDNS
json_output=$(jq '. + {"cjdns": 0}' <<<"$json_output")
cjdroute=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl cjdroute | awk '{print $1}')
if [ -n "$cjdroute" ]; then
    json_output=$(jq --argjson cjdroute "$cjdroute" '.cjdns = $cjdroute' <<<"$json_output")
fi

# AnodeVPN Server
json_output=$(jq '. + {"anodeserver": 0}' <<<"$json_output")
anodeserver=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} sh -c "pgrep -a node | grep -v node_exporter" | awk '{print $1}')
if [ -n "$anodeserver" ]; then
    json_output=$(jq --argjson anodeserver "$anodeserver" '.anodeserver = $anodeserver' <<<"$json_output")
fi

# IKEv2 
json_output=$(jq '. + {"ikev2": 0}' <<<"$json_output")
ikev2=$(docker ps -a | grep pkt-server | awk '{print $1}' | xargs -I {} docker exec {} sh -c "pgrep -a pluto | grep -v _plutorun" | awk '{print $1}')
if [ -n "$ikev2" ]; then
    json_output=$(jq --argjson ikev2 "$ikev2" '.ikev2 = $ikev2' <<<"$json_output")
fi

# OpenVPN
json_output=$(jq '. + {"openvpn": 0}' <<<"$json_output")
openvpn=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl openvpn | awk '{print $1}')
if [ -n "$openvpn" ]; then
    json_output=$(jq --argjson openvpn "$openvpn" '.openvpn = $openvpn' <<<"$json_output")
fi

# CJDNS Watchdog
json_output=$(jq '. + {"cjdns_watchdog": 0}' <<<"$json_output")
cjdns_wd=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl cjdns_watchdog | awk '{print $1}')
if [ -n "$cjdns_wd" ]; then
    json_output=$(jq --argjson cjdns_watchdog "$cjdns_wd" '.cjdns_watchdog = $cjdns_watchdog' <<<"$json_output")
fi

# VPN Watchdog
json_output=$(jq '. + {"vpn_watchdog": 0}' <<<"$json_output")
vpn_wd=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl vpn_watchdog | awk '{print $1}')
if [ -n "$vpn_wd" ]; then
    json_output=$(jq --argjson vpn_wd "$vpn_wd" '.vpn_watchdog = $vpn_wd' <<<"$json_output")
fi

# Add current date and time
current_date_time=$(date '+%Y-%m-%d %H:%M:%S')
json_output=$(jq --arg current_date_time "$current_date_time" '. + {date_time: $current_date_time}' <<<"$json_output")

echo $json_output | jq .