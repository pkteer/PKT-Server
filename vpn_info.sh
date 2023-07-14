#!/bin/bash
# Print out VPN Exit info
publicip=$(curl http://v4.vpn.anode.co/api/0.3/vpn/clients/ipaddress/ 2>/dev/null | jq -r .ipAddress)
publickey=$(cat ./data/cjdroute.conf | jq -r .publicKey)
cjdnsip=$(cat ./data/cjdroute.conf | jq -r .ipv6)
login=$(cat ./data/cjdroute.conf | jq -r .authorizedPasswords[0].user)
password=$(cat ./data/cjdroute.conf | jq -r .authorizedPasswords[0].password)
if [ -f /data/env/port ]; then
    CJDNS_PORT=$(cat ./data/env/port)
else
    echo "Server has not been configured. Exiting..."
    echo "RUN: docker run -it --rm -v $(pwd)/data:/data pkt-server /configure.sh"
    exit
fi
if [ -f /data/env/vpnname ]; then
    PKTEER_NAME=$(cat ./data/env/vpnname)
else
    echo "Enter VPN Server name:"
    read PKTEER_NAME
    echo $PKTEER_NAME > ./data/env/vpnname
fi
if [ -f /data/env/vpncountry ]; then
    PKTEER_COUNTRY=$(cat ./data/env/vpncountry)
else
    echo "Enter VPN Server country:"
    read PKTEER_COUNTRY
    echo $PKTEER_COUNTRY > ./data/env/vpncountry
fi
if [ -f /data/env/vpnusername ]; then
    PKTEER_CHAT_USERNAME=$(cat ./data/env/vpnusername)
else
    echo "Enter PKT.chat username:"
    read PKTEER_CHAT_USERNAME
    echo $PKTEER_CHAT_USERNAME > ./data/env/vpnusername
fi
if [ -f /data/env/vpnprice ]; then
    PKTEER_PREMIUM_PRICE=$(cat ./data/env/vpnprice)
else
    echo "Enter VPN Server price:"
    read PKTEER_PREMIUM_PRICE
    echo $PKTEER_PREMIUM_PRICE > ./data/env/vpnprice
fi

get_country_code() {
    local country_name="$1"
    local country_code=$(curl -s "https://restcountries.com/v2/name/$country_name?fullText=true" | jq -r '.[0].alpha2Code')
    if [[ -n "$country_code" && "$country_code" != "null" ]]; then
        echo "$country_code"
    else
        echo "Country code not found for '$country_name'" >&2
        exit 1
    fi
}

echo "-----------------Anode VPN Exit Info-----------------"
echo "Name: $PKTEER_NAME"
echo "Country: $PKTEER_COUNTRY"
echo "Public key: $publickey"
echo "Cjdns public ip: $cjdnsip"
echo "Public ip: $publicip"
echo "Cjdns public port: $CJDNS_PORT"
echo "Authorization server url: http://$publicip:$CJDNS_PORT"
echo "login: $login"
echo "password: $password"
echo "PKT.chat username: $PKTEER_CHAT_USERNAME"
echo "-----------------------------------------------------"
curl -X POST -H 'content-type: application/json' -d '{"text":"Adding VPN Server: **'"$PKTEER_NAME"'**\n    Country: '"$PKTEER_COUNTRY"'\n    Public key: '"$publickey"'\n    Cjdns public ip: '"$cjdnsip"'\n    Cjdns public port: '$CJDNS_PORT'\n    Public ip: '"$publicip"'\n    Authorization server: http://'$publicip':'$CJDNS_PORT'\n    login: '"$login"'\n    password: '"$password"'\n    username: @'$PKTEER_CHAT_USERNAME'\n    cost: '$PKTEER_PREMIUM_PRICE'"}' https://pkt.chat/hooks/5tx5ebhuzpgh3dk5ys9rpt5yxr

echo "Getting country code..."
country_code=$(get_country_code "$PKTEER_COUNTRY")
output=$(curl -X POST -H "Content-Type: application/json" -d '{
    "vpn_server": {
        "name":"'"$PKTEER_NAME"'",
        "country_code":"'$country_code'",
        "public_key":"'$publickey'",
        "cjdns_public_ip":"'$cjdnsip'",
        "public_ip":"'$publicip'",
        "cjdns_public_port": '$CJDNS_PORT',
        "authorization_server_url":"http://'$publicip':'$CJDNS_PORT'",
        "cost": '$PKTEER_PREMIUM_PRICE'
        }, 
        "peeringline": {
            "name": "'$PKTEER_CHAT_USERNAME'",
            "login":"'$login'",
            "password":"'$password'"
        }
    }' https://vpn.anode.co/api/0.4/vpn/servers/addcjdnsvpnserver )

echo "Output: $output"
output=$(echo $output | sed 's/\"//g')
if [ "${output,,}" = "ok" ]; then
   echo "VPN Server successfully added to ANODE VPN"
   curl -X POST -H 'content-type: application/json' -d '{"text":"New VPN Server **'"$PKTEER_NAME"'** added."}' https://pkt.chat/hooks/5tx5ebhuzpgh3dk5ys9rpt5yxr
else
   curl -X POST -H 'content-type: application/json' -d '{"text":"Failed to add new VPN Server **'"$PKTEER_NAME"'** with message: '"$output"'."}' https://pkt.chat/hooks/5tx5ebhuzpgh3dk5ys9rpt5yxr
   echo "There was a problem with adding VPN Server: $output"
fi