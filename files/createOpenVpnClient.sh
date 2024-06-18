#!/bin/bash

if [ -z "$1" ]
then
    echo "No username supplied. Exiting."
    exit 1
else
    username="$1"
    echo "Generating Openvpn profile for $username"
fi

ca_crt="/etc/openvpn/ca.crt"

if [[ ! -f $ca_crt ]]; then
    echo "Error: $ca_crt does not exist."
    exit 1
fi

# Read openvpn password
password=$(cat /data/config.json | jq -r '.openvpn_password')

if [ -z "$password" ]
then
    echo "No openvpn password found in config.json file. Exiting."
    exit 1
fi

# Create client certificate
cd /openvpn/easy-rsa
#./easyrsa gen-req $username nopass
/usr/bin/expect <<EOF
spawn ./easyrsa gen-req $username nopass
expect "Common Name (eg: your user, host, or server name) "
send "\r"
expect eof
EOF

#./easyrsa sign-req client $username
/usr/bin/expect <<EOF
spawn ./easyrsa sign-req client $username
expect "Confirm request details:"
send "yes\r"
expect "Enter pass phrase for /openvpn/easy-rsa/pki/private/ca.key:"
send "$password\r"
expect eof
EOF

client_crt="/openvpn/easy-rsa/pki/issued/$username.crt"
client_key="/openvpn/easy-rsa/pki/private/$username.key"

if [[ ! -f $client_crt ]]; then
    echo "Error: $client_crt does not exist."
    exit 1
fi

if [[ ! -f $client_key ]]; then
    echo "Error: $client_key does not exist."
    exit 1
fi

ovpn_file="/server/vpnclients/$username.ovpn"

serverPublicIp=$(curl -s https://api.ipify.org)

mkdir -p /server/vpnclients

echo "client" > $ovpn_file
echo "dev tun" >> $ovpn_file
echo "proto udp" >> $ovpn_file
echo "remote $serverPublicIp 1194" >> $ovpn_file
echo "resolv-retry infinite" >> $ovpn_file
echo "nobind" >> $ovpn_file
echo "persist-key" >> $ovpn_file
echo "persist-tun" >> $ovpn_file
echo "cipher AES-256-CBC" >> $ovpn_file
echo "auth SHA256" >> $ovpn_file
echo "key-direction 1" >> $ovpn_file
echo "remote-cert-tls server" >> $ovpn_file
echo "verb 3" >> $ovpn_file
echo "" >> $ovpn_file

# Add the CA certificate to the output file
echo "<ca>" >> $ovpn_file
cat $ca_crt >> $ovpn_file
echo "</ca>" >> $ovpn_file

# Add the client certificate to the output file
echo "<cert>" >> $ovpn_file
cat $client_crt >> $ovpn_file
echo "</cert>" >> $ovpn_file

# Add the client key to the output file
echo "<key>" >> $ovpn_file
cat $client_key >> $ovpn_file
echo "</key>" >> $ovpn_file
