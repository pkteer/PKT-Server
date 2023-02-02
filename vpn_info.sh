#!/bin/bash
# Print out VPN Exit info
publicip=$(curl http://v4.vpn.anode.co/api/0.3/vpn/clients/ipaddress/ 2>/dev/null | jq -r .ipAddress)
publickey=$(cat /server/cjdns/cjdroute.conf | jq -r .publicKey)
cjdnsip=$(cat /server/cjdns/cjdroute.conf | jq -r .ipv6)
login=$(cat /server/cjdns/cjdroute.conf | jq -r .authorizedPasswords[0].user)
password=$(cat /server/cjdns/cjdroute.conf | jq -r .authorizedPasswords[0].password)
echo "Provide a name for your VPN Exit and country of exit along with the following information to the administrator to enable your VPN server"
#echo "Name: "
echo "Public key: $publickey"
echo "Cjdns public ip: $cjdnsip"
echo "Public ip: $publicip"
echo "Cjdns public port: 47512"
echo "Authorization server url: http://51.222.109.102:8099"
echo "login: $login"
echo "password: $password"