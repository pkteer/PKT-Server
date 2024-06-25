#!/bin/sh

passphrase="pktvpn"
apt-get install openvpn easy-rsa
apt-get install expect

echo "Copying openvpn configuration..."
if [ -z "$PKT_HOSTNAME" ]
then
    echo "PKT_HOSTNAME not set, exiting..."
    exit 1
else
    mv /server/openvpn.conf /etc/openvpn/$PKT_HOSTNAME.conf
fi

echo "Generating certificates..."
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa/

./easyrsa init-pki
./easyrsa build-ca
#TODO: key passphrase, twice and common name "hostname"

./easyrsa gen-req $PKT_HOSTNAME nopass
./easyrsa gen-dh
./easyrsa sign-req server $PKT_HOSTNAME
#TODO: confirm with 'yes' and add pasphrase
cp pki/dh.pem pki/ca.crt pki/issued/$PKT_HOSTNAME.crt pki/private/$PKT_HOSTNAME.key /etc/openvpn/

./easyrsa gen-req pktvpnclient nopass
#TODO confirm with 'yes' and commonname "pktvpnclient"
./easyrsa sign-req client pktvpnclient
#TODO confirm with 'yes' and add passphrase

echo "Editing openvpn configuration..."
sed -i 's/{{HOSTNAME}}/$PKT_HOSTNAME/g' /etc/openvpn/$PKT_HOSTNAME.conf

echo "Copying openvpn client files..."
cp /etc/openvpn/easy-rsa/pki/issued/pktvpnclient.crt /data/
cp /etc/openvpn/easy-rsa/pki/private/pktvpnclient.key /data/
cp /etc/openvpn/ca.crt /data/

