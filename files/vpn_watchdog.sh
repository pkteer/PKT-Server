#!/bin/bash

vpnClientsFile="/server/anodevpn-server/vpnclients.json"
directory="/server/vpnclients/"
duration=$(date -d '1 month ago' +%s%3N)
ipsec_process="/usr/local/libexec/ipsec/pluto"
vpn_script="/server/vpn.sh"
openvpn_script="openvpn --config "

echo "Checking if ipsec is running..."
if ! pgrep -f $ipsec_process > /dev/null
then
    echo "$ipsec_process is not running, starting it now..."
    bash $vpn_script
fi
echo "Checking if openvpn is running..."
if ! pgrep -f openvpn > /dev/null
then
    openvpnConfigFile=$(ls /data/openvpn/*.conf)
    echo "openvpn is not running, starting it with $openvpnConfigFile..."
    $openvpn_script $openvpnConfigFile
fi

revokeOvpnClient() {
    local username=$1
    local openvpn_script=$2
    local openvpnConfigFile=$(ls /data/openvpn/*.conf)
    local password=$(cat /data/config.json | jq -r '.openvpn_password')
    cd /etc/openvpn/easy-rsa
    /usr/bin/expect <<EOF
spawn ./easyrsa revoke $username
expect "Continue with revocation:"
send "yes\r"
expect "Enter pass phrase for /etc/openvpn/easy-rsa/pki/private/ca.key:"
send "$password\r"
expect eof
EOF
    /usr/bin/expect <<EOF
spawn ./easyrsa gen-crl
expect "Enter pass phrase for /etc/openvpn/easy-rsa/pki/private/ca.key:"
send "$password\r"
expect eof
EOF
    cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
    # Restart openvpn
    killall openvpn
    bash $openvpn_script $openvpnConfigFile
}


size=$(jq '.clients | length' $vpnClientsFile)
echo "Checking for expired vpn clients..."
for (( i=$((size-1)); i>=0; i-- ))
do
    timeCreated=$(jq -r ".clients[$i].timeCreated" $vpnClientsFile)
    username=$(jq -r ".clients[$i].username" $vpnClientsFile)
    if (( timeCreated < duration )); then
        echo "$username: Duration has passed from $timeCreated"
        rmFile="$directory$username.*"
        if [ -e $rmFile ]; then
            echo "Deleting $rmFile"
            rm $rmFile
        else
            echo "File $rmFile does not exist"
        fi
        echo "Removing $username from $vpnClientsFile"
        jq "del(.clients[$i])" $vpnClientsFile > temp.json && mv temp.json $vpnClientsFile
        #Revoking clients from ikev2
/usr/bin/expect <<EOF
spawn /usr/bin/ikev2.sh --revokeclient $username
expect "Are you sure you want to revoke"
send "y\r"
expect eof
EOF
        ovpnFile="/server/vpnclients/$username.ovpn"
        if [ -e "$ovpnFile" ]; then
            echo "Revoking $username from openvpn"
            revokeOvpnClient $username $openvpn_script
        else
            echo "File $ovpnFile does not exist"
        fi
    fi
done
