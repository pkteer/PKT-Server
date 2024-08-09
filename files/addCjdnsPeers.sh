#!/bin/bash

cjdrouteFile="/data/cjdroute.conf"
publicip=$(curl http://v4.vpn.anode.co/api/0.3/vpn/clients/ipaddress/ 2>/dev/null | jq -r .ipAddress)
publickey=$(cat $cjdrouteFile | jq -r .publicKey)
cjdnsip=$(cat $cjdrouteFile | jq -r .ipv6)
login=$(cat $cjdrouteFile | jq -r .authorizedPasswords[0].user)
password=$(cat $cjdrouteFile | jq -r .authorizedPasswords[0].password)
CJDNS_PORT=$(cat $cjdrouteFile | jq -r '.interfaces.UDPInterface[0].bind' | sed 's/^.*://')
name=$(cat /data/config.json | jq -r .hostname)

json=$(curl --max-time 10 -X POST -H "Content-Type: application/json" -d '{
  "name": "'"$name"'",
  "login": "'"$login"'",
  "password": "'"$password"'",
  "ip": "'"$publicip"'",
  "ip6": "'"$cjdnsip"'",
  "port": '"$CJDNS_PORT"',
  "publicKey": "'"$publickey"'"
}' http://diffie.pkteer.com:8090/api/peers || cat /server/cjdnspeers.json)

# Parse the JSON data and execute the command for each server
echo "$json" | jq -r '.[] | "\(.publicKey) \(.ip):\(.port) \(.login) \(.password)"' | while read -r line
do
    publicKey=$(echo $line | cut -d' ' -f1)
    ipAndPort=$(echo $line | cut -d' ' -f2)
    login=$(echo $line | cut -d' ' -f3)
    password=$(echo $line | cut -d' ' -f4)
    /server/cjdns/tools/cexec "UDPInterface_beginConnection(\"$publicKey\",\"$ipAndPort\",0,\"\",\"$password\",\"$login\",0)"
done