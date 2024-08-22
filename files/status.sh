#!/bin/bash

# check if script is being run inside or outside the container
inside=false
if [ -f /.dockerenv ]; then
    inside=true
fi
dockername="pkt-server"

config_path="vpn_data/config.json"
if [ "$inside" = true ]; then
  config_path="/data/config.json"
fi

# hostname
hostname=$(cat $config_path | jq -r '.hostname')

# Initialize an empty JSON object
json_output=$(jq -n '{}')

json_output=$(jq --arg hostname "$hostname" '. + {hostname: $hostname}' <<<"$json_output")

# PKT wallet
json_output=$(jq '. + {"pktwallet": 0}' <<<"$json_output")
if [ "$inside" = true ]; then
    pld=$(pgrep -fl pld | awk '{print $1}')
else 
    pld=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl pld | awk '{print $1}')
fi
if [ -n "$pld" ]; then
    json_output=$(jq --argjson pld "$pld" '.pktwallet = $pld' <<<"$json_output")
fi

# CJDNS
json_output=$(jq '. + {"cjdns": 0}' <<<"$json_output")
if [ "$inside" = true ]; then
    cjdroute=$(pgrep -fl cjdroute | awk '{print $1}' | head -n 1)
else
    cjdroute=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl cjdroute | awk '{print $1}' | head -n 1)
fi
if [ -n "$cjdroute" ]; then
    json_output=$(jq --argjson cjdroute "$cjdroute" '.cjdns = $cjdroute' <<<"$json_output")
fi

# AnodeVPN Server
json_output=$(jq '. + {"anodeserver": 0}' <<<"$json_output")
if [ "$inside" = true ]; then
    anodeserver=$(pgrep -a node | grep -v node_exporter | awk '{print $1}')
else
    anodeserver=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} sh -c "pgrep -a node | grep -v node_exporter" | awk '{print $1}')
fi
if [ -n "$anodeserver" ]; then
    json_output=$(jq --argjson anodeserver "$anodeserver" '.anodeserver = $anodeserver' <<<"$json_output")
fi

# IKEv2 
json_output=$(jq '. + {"ikev2": 0}' <<<"$json_output")
if [ "$inside" = true ]; then
    ikev2=$(pgrep -a pluto | grep -v _plutorun | awk '{print $1}')
else
    ikev2=$(docker ps -a | grep pkt-server | awk '{print $1}' | xargs -I {} docker exec {} sh -c "pgrep -a pluto | grep -v _plutorun" | awk '{print $1}')
fi
if [ -n "$ikev2" ]; then
    json_output=$(jq --argjson ikev2 "$ikev2" '.ikev2 = $ikev2' <<<"$json_output")
fi

# OpenVPN
json_output=$(jq '. + {"openvpn": 0}' <<<"$json_output")
if [ "$inside" = true ]; then
    openvpn=$(pgrep -fl openvpn | awk '{print $1}')
else
    openvpn=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl openvpn | awk '{print $1}')
fi
if [ -n "$openvpn" ]; then
    json_output=$(jq --argjson openvpn "$openvpn" '.openvpn = $openvpn' <<<"$json_output")
fi

# SNIProxy
json_output=$(jq '. + {"sniproxy": 0}' <<<"$json_output")
if [ "$inside" = true ]; then
    sniproxy=$(pgrep -fl sniproxy | awk '{print $1}' | head -n 1)
else
    sniproxy=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl sniproxy | awk '{print $1}' | head -n 1)
fi
if [ -n "$sniproxy" ]; then
    json_output=$(jq --argjson sniproxy "$sniproxy" '.sniproxy = $sniproxy' <<<"$json_output")
fi

# CJDNS Watchdog
json_output=$(jq '. + {"watchdog": 0}' <<<"$json_output")
if [ "$inside" = true ]; then
    wd=$(pgrep -fl watchdog | awk '{print $1}')
else
    wd=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} pgrep -fl watchdog | awk '{print $1}')
fi
if [ -n "$wd" ]; then
    json_output=$(jq --argjson watchdog "$wd" '.watchdog = $watchdog' <<<"$json_output")
fi

# Add peers section
if [ "$inside" = true ]; then
    peer_stats=$(/server/cjdns/tools/peerStats)
    peers=$(echo "$peer_stats" | awk '{print $1, $3}' | sed 's/\.k//g' | awk '{print "{\"ip\":\""$1"\", \"status\":\""$2"\"}"}' | jq -s .)
else
    peers=$(docker ps -a | grep $dockername | awk '{print $1}' | xargs -I {} docker exec {} /server/cjdns/tools/peerStats | awk '{print $1, $3}' | sed 's/\.k//g' | awk '{print "{\"ip\":\""$1"\", \"status\":\""$2"\"}"}' | jq -s .)
fi
json_output=$(jq --argjson peers "$peers" '. + {"peers": $peers}' <<<"$json_output")

# Add current date and time
current_date_time=$(date '+%Y-%m-%d %H:%M:%S')
json_output=$(jq --arg current_date_time "$current_date_time" '. + {date_time: $current_date_time}' <<<"$json_output")

echo $json_output | jq .