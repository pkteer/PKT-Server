#!/bin/bash
update_json() {
    local key=$1
    local value=$2
    local jq_expression

    if [[ "$value" == "true" || "$value" == "false" ]]; then
        jq_value="$value"
    else
        jq_value="\"$value\""
    fi

    # Check if the key is nested
    if [[ "$key" == *.* ]]; then
        # For nested keys, construct the jq path correctly
        IFS='.' read -ra KEYS <<< "$key"
        jq_path=".${KEYS[0]}"
        for i in "${KEYS[@]:1}"; do
            jq_path+="[\"$i\"]"
        done
        jq_expression="$jq_path = $jq_value"
    else
        jq_expression=".\"$key\" = $jq_value"
    fi

    jq "$jq_expression" config.json > temp.json && mv temp.json config.json
}
echo "Welcome to PKT Server setup script!"
echo "This script will guide you through the setup process."

# set hostname
echo "Whats the hostname of this server?"
read hostname
update_json "hostname" "$hostname"

# set region and city for timezone
echo "Enter server's region for timezone. (eg. America,Europe,Asia,Africa,Australia)"
read region
echo "Enter the city for the timezone. (eg. New_York,Paris,London,Seoul)"
read city
update_json "region" "$region"
update_json "city" "$city"

# enable cjdns
echo "Do you want to enable CJDNS service? (true/false) Default [true]"
read cjdns
cjdns=${cjdns:-true}
update_json "cjdns.enabled" "$cjdns"

echo "Do you want to enable VPN exit for CJDNS service? (true/false) Default [false]"
read cjdns_vpn_exit
cjdns_vpn_exit=${cjdns_vpn_exit:-false}
update_json "cjdns.vpn_exit" "$cjdns_vpn_exit"

echo "Do you want to expose RPC for CJDNS service? (true/false) Default [false]"
read cjdns_expose_rpc
cjdns_expose_rpc=${cjdns_expose_rpc:-false}
update_json "cjdns.expose_rpc" "$cjdns_expose_rpc"

#pktd service
echo "Do you want to enable pktd service? (true/false) Default [false]"
read pktd_enabled
pktd_enabled=${pktd_enabled:-false}
update_json "pktd.enabled" "$pktd_enabled"

echo "Do you want to enable public RPC for pktd service? (true/false) Default [true]"
read pktd_public_rpc
pktd_public_rpc=${pktd_public_rpc:-true}
update_json "pktd.public_rpc" "$pktd_public_rpc"

echo "Do you want to enable CJDNS RPC for pktd service? (true/false) Default [true]"
read pktd_cjdns_rpc
pktd_cjdns_rpc=${pktd_cjdns_rpc:-true}
update_json "pktd.cjdns_rpc" "$pktd_cjdns_rpc"

echo "Enter RPC user for pktd service: (leave blank for 'x')"
read pktd_rpcuser
pktd_rpcuser=${pktd_rpcuser:-x}
update_json "pktd.rpcuser" "$pktd_rpcuser"

echo "Enter RPC password for pktd service: "
read pktd_rpcpass
update_json "pktd.rpcpass" "$pktd_rpcpass"

echo "Enter your PKT address where you want to receive payments: "
read pkt_pay_to_address
update_json "pkt.pay_to_address" "$pkt_pay_to_address"

# enable ikev2 service
echo "Do you want to enable IKEv2 service? (true/false)"
read ikev2
update_json "ikev2.enabled" "$ikev2"
if [ "$ikev2" == "true" ]; then
    echo "IKEv2 service enabled."
    # set default client true/false
    # set default client username, password, sharedkey
    echo "Do you want to set a default vpn client for IKEv2 service? (true/false)"
    read ikev2_client
    update_json "ikev2.client.enabled" "$ikev2_client"
    if [ "$ikev2_client" == "true" ]; then
        echo "IKEv2 client enabled."
        echo "Enter the username for the default IKEv2 client."
        read ikev2_client_username
        echo "Enter the password for the default IKEv2 client."
        read ikev2_client_password
        echo "Enter the shared key for the default IKEv2 client."
        read ikev2_client_sharedkey
        update_json "ikev2.client.username" "$ikev2_client_username"
        update_json "ikev2.client.password" "$ikev2_client_password"
        update_json "ikev2.client.sharedKey" "$ikev2_client_sharedkey"
    else
        echo "IKEv2 client disabled."
    fi
else
    echo "IKEv2 service disabled."
fi

# enable openvpn service
echo "Do you want to enable OpenVPN service? (true/false)"
read openvpn
update_json "openvpn.enabled" "$openvpn"
if [ "$openvpn" == "true" ]; then
    echo "OpenVPN service enabled."
    echo "Enter the passphrase for CA certificate generation."
    read openvpn_passphrase
    update_json "openvpn.passphrase" "$openvpn_passphrase"
else
    echo "OpenVPN service disabled."
fi

# enable sniproxy?
echo "Do you want to enable SNI Proxy service? (true/false)"
read sniproxy
update_json "sniproxy.enabled" "$sniproxy"
if [ "$sniproxy" == "true" ]; then
    echo "SNI Proxy service enabled."
else
    echo "SNI Proxy service disabled."
fi