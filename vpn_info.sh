#!/bin/bash
# Print out VPN Exit info
publicip=$(curl http://v4.vpn.anode.co/api/0.3/vpn/clients/ipaddress/ 2>/dev/null | jq -r .ipAddress)
publickey=$(cat /server/cjdns/cjdroute.conf | jq -r .publicKey)
cjdnsip=$(cat /server/cjdns/cjdroute.conf | jq -r .ipv6)
login=$(cat /server/cjdns/cjdroute.conf | jq -r .authorizedPasswords[0].user)
password=$(cat /server/cjdns/cjdroute.conf | jq -r .authorizedPasswords[0].password)

echo "-----------------Anode VPN Exit Info-----------------"
echo "Name: $PKTEER_NAME"
echo "Country: $PKTEER_COUNTRY"
echo "Public key: $publickey"
echo "Cjdns public ip: $cjdnsip"
echo "Public ip: $publicip"
echo "Cjdns public port: $ANODE_SERVER_PORT"
echo "Authorization server url: http://$publicip:$ANODE_SERVER_PORT"
echo "login: $login"
echo "password: $password"
echo "-----------------------------------------------------"
