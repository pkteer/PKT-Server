#!/bin/sh

echo "Copying openvpn configuration..."
if [ -z "$PKT_HOSTNAME" ]
then
    echo "PKT_HOSTNAME not set, using default openvpn.conf"
    mv /server/openvpn.conf /openvpn/openvpn.conf
else
    mv /server/openvpn.conf /openvpn/$PKT_HOSTNAME.conf
fi

echo "Generating certificates..."
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa/

./easyrsa init-pki

./easyrsa build-ca
