#!/bin/bash

update_json() {
  local key=$1
  local value=$2

  jq --arg key "$key" --arg value "$value" '.[$key] = $value' config.json > temp.json && mv temp.json config.json
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

# enable ikev2 service
echo "Do you want to enable IKEv2 service? (yes/no)"
read ikev2
update_json "ikev2.enabled" "$ikev2"
if [ "$ikev2" == "yes" ]; then
    echo "IKEv2 service enabled."
    # set default client yes/no
    # set default client username, password, sharedkey
    echo "Do you want to set a default vpn client for IKEv2 service? (yes/no)"
    read ikev2_client
    update_json "ikev2.client.enabled" "$ikev2_client"
    if [ "$ikev2_client" == "yes" ]; then
        echo "IKEv2 client enabled."
        echo "Enter the username for the default IKEv2 client."
        read ikev2_client_username
        echo "Enter the password for the default IKEv2 client."
        read ikev2_client_password
        echo "Enter the shared key for the default IKEv2 client."
        read ikev2_client_sharedkey
        update_json "ikev2.client.username" "$ikev2_client_username"
        update_json "ikev2.client.password" "$ikev2_client_password"
        update_json "ikev2.client.sharedkey" "$ikev2_client_sharedkey"
    else
        echo "IKEv2 client disabled."
    fi
else
    echo "IKEv2 service disabled."
fi

# enable openvpn service
echo "Do you want to enable OpenVPN service? (yes/no)"
read openvpn
update_json "openvpn.enabled" "$openvpn"
if [ "$openvpn" == "yes" ]; then
    echo "OpenVPN service enabled."
    echo "Enter the passphrase for CA certificate generation."
    read openvpn_passphrase
    update_json "openvpn.passphrase" "$openvpn_passphrase"
else
    echo "OpenVPN service disabled."
fi

# enable sniproxy?
echo "Do you want to enable SNI Proxy service? (yes/no)"
read sniproxy
update_json "sniproxy.enabled" "$sniproxy"
if [ "$sniproxy" == "yes" ]; then
    echo "SNI Proxy service enabled."
else
    echo "SNI Proxy service disabled."
fi