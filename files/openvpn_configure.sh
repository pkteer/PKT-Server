#!/bin/sh

password=$(cat /data/config.json | jq -r '.openvpn_password')
if [ -z "$password" ]; then
    echo "Password is empty. Please set the openvpn_password in config.json."
    exit 1
fi
hostname=$(cat /data/config.json | jq -r '.hostname')
if [ -z "$hostname" ]
then
    echo "hostname not set, Please set the hostname in config.json."
    exit 1
fi

apt-get install openvpn easy-rsa
apt-get install expect

if [ -f "/etc/openvpn/$hostname.conf" ]; then
    echo "The file /etc/openvpn/$hostname.conf already exists."
else
    echo "Copying openvpn configuration..."
    mv /server/openvpn.conf /etc/openvpn/$hostname.conf

    echo "Generating certificates..."
    make-cadir /etc/openvpn/easy-rsa
    cd /etc/openvpn/easy-rsa/

    ./easyrsa init-pki
    ./easyrsa build-ca
    #TODO: key passphrase, twice and common name "hostname"

    ./easyrsa gen-req $hostname nopass
    ./easyrsa gen-dh
    ./easyrsa sign-req server $hostname
    #TODO: confirm with 'yes' and add pasphrase
    cp pki/dh.pem pki/ca.crt pki/issued/$hostname.crt pki/private/$hostname.key /etc/openvpn/

    ./easyrsa gen-req pktvpnclient nopass
    #TODO confirm with 'yes' and commonname "pktvpnclient"
    ./easyrsa sign-req client pktvpnclient
    #TODO confirm with 'yes' and add passphrase

    echo "Editing openvpn configuration..."
    sed -i "s/{{HOSTNAME}}/${hostname}/g" /etc/openvpn/$hostname.conf

    ./easyrsa gen-crl
    cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
fi
echo "Copying openvpn client files..."
cp /etc/openvpn/easy-rsa/pki/issued/pktvpnclient.crt /data/
cp /etc/openvpn/easy-rsa/pki/private/pktvpnclient.key /data/
cp /etc/openvpn/ca.crt /data/

