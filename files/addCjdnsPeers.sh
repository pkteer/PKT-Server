#!/bin/bash

cjdrouteFile="/data/cjdroute.conf"
cjdnstoolspath="/server/cjdns/tools"
publicip=$(curl http://v4.vpn.anode.co/api/0.3/vpn/clients/ipaddress/ 2>/dev/null | jq -r .ipAddress)
publickey=$(cat $cjdrouteFile | jq -r .publicKey)
cjdnsip=$(cat $cjdrouteFile | jq -r .ipv6)
login=$(cat $cjdrouteFile | jq -r .authorizedPasswords[0].user)
password=$(cat $cjdrouteFile | jq -r .authorizedPasswords[0].password)
CJDNS_PORT=$(cat $cjdrouteFile | jq -r '.interfaces.UDPInterface[0].bind' | sed 's/^.*://')
name=$(cat /data/config.json | jq -r .hostname)

#Check current peers and their status
peerStats=$($cjdnstoolspath/peerStats)
peersCount=$(echo "$peerStats" | wc -l)
removedPeers=0
echo "Checking status of existing $peersCount peers"
while read -r line; do
    status=$(echo "$line" | awk '{print $3}')
    if [ "$status" != "ESTABLISHED" ]; then
        peerpublickey=$(echo "$line" | awk '{print $2}' | cut -d'.' -f6-)
        # Disconnect from peers that are not ESTABLISHED
        echo "Disconnecting from peer $peerpublickey"
        $cjdnstoolspath/cexec "InterfaceController_disconnectPeer('$peerpublickey')"
        removedPeers=$((removedPeers + 1))
    fi
done < <(echo "$peerStats")
remainingPeers=$((peersCount - removedPeers))
 
if [ "$remainingPeers" -lt 3 ]; then
  echo "We have $remainingPeers peers. Adding more peers."
  json=$(curl --max-time 10 -X POST -H "Content-Type: application/json" -d '{
    "name": "'"$name"'",
    "login": "'"$login"'",
    "password": "'"$password"'",
    "ip": "'"$publicip"'",
    "ip6": "'"$cjdnsip"'",
    "port": '"$CJDNS_PORT"',
    "publicKey": "'"$publickey"'"
  }' http://diffie.pkteer.com:8090/api/peers || cat /server/cjdnspeers.json)

  # Parse the JSON data and execute the command for each server, until we have 3 peers
  echo "$json" | jq -r '.[] | "\(.publicKey) \(.ip):\(.port) \(.login) \(.password)"' | while read -r line
  do
      publicKey=$(echo $line | cut -d' ' -f1)
      ipAndPort=$(echo $line | cut -d' ' -f2)
      login=$(echo $line | cut -d' ' -f3)
      password=$(echo $line | cut -d' ' -f4)
      $cjdnstoolspath/cexec "UDPInterface_beginConnection(\"$publicKey\",\"$ipAndPort\",0,\"\",\"$password\",\"$login\",0)"
      peerStats=$($cjdnstoolspath/peerStats)
      peersCount=$(echo "$peerStats" | wc -l)
      if [ "$peersCount" -eq 3 ]; then
        echo "We now have 3 peers. Exiting."
        exit 0
      fi
  done
fi