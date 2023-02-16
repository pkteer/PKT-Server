#!/bin/bash
# Print out VPN Exit info
publicip=$(curl http://v4.vpn.anode.co/api/0.3/vpn/clients/ipaddress/ 2>/dev/null | jq -r .ipAddress)
publickey=$(cat /server/cjdns/cjdroute.conf | jq -r .publicKey)
cjdnsip=$(cat /server/cjdns/cjdroute.conf | jq -r .ipv6)
login=$(cat /server/cjdns/cjdroute.conf | jq -r .authorizedPasswords[0].user)
password=$(cat /server/cjdns/cjdroute.conf | jq -r .authorizedPasswords[0].password)

echo "-----------------Anode VPN Exit Info-----------------"
echo "Public key: $publickey"
echo "Cjdns public ip: $cjdnsip"
echo "Public ip: $publicip"
echo "Cjdns public port: 47512"
echo "Authorization server url: http://$publicip:8099"
echo "login: $login"
echo "password: $password"
echo "-----------------------------------------------------"

curl -X POST -H "Host: pkt.chat" -H "Content-Type: application/json" -d '{"text":"Name: '$PKTEER_NAME' \nCountry: '$PKTEER_COUNTRY'\nPublic key: '$publickey' \nCjdns public ip: '$cjdnsip' \nPublic ip: '$publicip' \nCjdns public port: 47512 \nAuthorization server url: http://'$publicip':8099 \nlogin: '$login' \npassword: '$password'"}' https://pkt.chat/hooks/$PKTEER_WEBHOOK