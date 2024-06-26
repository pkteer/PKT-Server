#!/bin/bash
# Fetch the JSON data
#json=$(curl -s https://vpn.anode.co/api/0.4/vpn/cjdns/peeringlines/)
json=$(cat /server/cjdnspeers.json)
# Parse the JSON data and execute the command for each server
echo "$json" | jq -r '.[] | "\(.publicKey) \(.ip):\(.port) \(.login) \(.password)"' | while read -r line
do
    publicKey=$(echo $line | cut -d' ' -f1)
    ipAndPort=$(echo $line | cut -d' ' -f2)
    login=$(echo $line | cut -d' ' -f3)
    password=$(echo $line | cut -d' ' -f4)
    /server/cjdns/tools/cexec "UDPInterface_beginConnection(\"$publicKey\",\"$ipAndPort\",0,\"\",\"$password\",\"$login\",0)"
done