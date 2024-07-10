#!/bin/sh

password=$(cat /data/config.json | jq -r '.openvpn.passphrase')
if [ -z "$password" ]; then
    echo "Password is empty. Please set the openvpn passphrase in config.json."
    exit 1
fi
hostname=$(cat /data/config.json | jq -r '.hostname')
if [ -z "$hostname" ]
then
    echo "hostname not set, Please set the hostname in config.json."
    exit 1
fi

if [ -f "/etc/openvpn/$hostname.conf" ]; then
    echo "The file /etc/openvpn/$hostname.conf already exists."
else
    echo "Copying openvpn configuration..."
    mv /server/openvpn.conf /etc/openvpn/$hostname.conf

    echo "Generating certificates..."
    make-cadir /etc/openvpn/easy-rsa
    cd /etc/openvpn/easy-rsa/
    if [ -d "/etc/openvpn/easy-rsa/pki" ]; then
        echo "pki already exists."
    else
        echo "Initializing pki..."
        ./easyrsa init-pki
    fi
    if [ -f "/etc/openvpn/pki/ca.crt" ]; then
        echo "CA certificate already exists."
    else
        echo "Generating new CA certificate..."
        /usr/bin/expect <<EOF
spawn ./easyrsa build-ca
expect "Enter New CA Key Passphrase: "
send "$password\r"
expect "Re-Enter New CA Key Passphrase:"
send "$password\r"
expect "Common Name (eg: your user, host, or server name) "
send "$hostname\r"
expect eof
EOF
    fi
    

/usr/bin/expect <<EOF
spawn ./easyrsa gen-req $hostname nopass
expect "Common Name (eg: your user, host, or server name) "
send "yes\r"
expect eof
EOF

    ./easyrsa gen-dh
/usr/bin/expect <<EOF
spawn ./easyrsa sign-req server $hostname
expect "Confirm request details:"
send "yes\r"
expect "Enter pass phrase for /etc/openvpn/easy-rsa/pki/private/ca.key:"
send "$password\r"
expect eof
EOF

    cp pki/dh.pem pki/ca.crt pki/issued/$hostname.crt pki/private/$hostname.key /etc/openvpn/

    echo "Editing openvpn configuration..."
    sed -i "s/{{HOSTNAME}}/${hostname}/g" /etc/openvpn/$hostname.conf
/usr/bin/expect <<EOF
spawn ./easyrsa gen-crl
expect "Enter pass phrase for /etc/openvpn/easy-rsa/pki/private/ca.key:"
send "$password\r"
expect eof
EOF

    cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
fi
