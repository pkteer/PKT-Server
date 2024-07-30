#!/bin/bash
vpnClientsFile="/server/anodevpn-server/vpnclients.json"
directory="/server/vpnclients/"
duration=$(date -d '1 month ago' +%s%3N)
ipsec_process="/usr/local/libexec/ipsec/pluto"
vpn_script="/server/vpn.sh"
openvpn_script="openvpn --config "


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
    $openvpn_script $openvpnConfigFile
}

checkVpnClients() {
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
}

restart() {
    # Kill cjdroute
    pkill cjdroute
    if pidof cjdroute > /dev/null; then
        pkill -9 cjdroute
    fi

    # Kill node
    kill $(ps aux | pgrep -x node)

    # Set CAP_NET_ADMIN to cjdroute
    setcap cap_net_admin=eip /server/cjdns/cjdroute

    # Launch cjdns
su - cjdns <<EOF
/server/cjdns/cjdroute < /data/cjdroute.conf &
EOF
    # Add cjdnsPeers
    /server/addCjdnsPeers.sh
    if [ "$AKASH" != true ]; then
        # Launch node
        if [ -e /data/env/vpnprice ]; then
            export PKTEER_PREMIUM_PRICE=$(cat /data/env/vpnprice)
        else
            # Default price
            export PKTEER_PREMIUM_PRICE=10
        fi
        node /server/anodevpn-server/index.js &
    fi
    sleep 2
    # Add route
    ip route add 10.0.0.0/8 dev tun0
}

while true; do
    # use timeout in case cjdroute is not running
    cjdroute=$(ps aux | pgrep -x cjdroute)
    if [ -z "$cjdroute" ]; then
        echo "cjdns is not running, restarting..."
        restart
    else
        echo "$(date): cjdns is running."
    fi
    sleep 2
    if [ "$AKASH" != true ]; then
        # Check that anodevpn-server is running
        node=$(ps aux | pgrep -x node)
        if [ -z "$node" ]; then
            echo "anodevpn-server is not running, restarting..."
            restart
        else
            response=$(curl --write-out %{http_code} --silent --connect-timeout 5 --output /dev/null http://localhost:8099/healthcheck)
            if [ "$response" -eq 200 ]; then
                echo "$(date): anodevpn-server is running."
            else
                echo "anodevpn-server is running but not responding, restarting..."
                restart
            fi
        fi
        sleep 1

        echo "Checking if ipsec is running..."
        if ! pgrep -f $ipsec_process > /dev/null
        then
            echo "$ipsec_process is not running, starting it now..."
            $vpn_script
        fi
        echo "Checking if openvpn is running..."
        if ! pgrep -f openvpn > /dev/null
        then
            openvpnConfigFile=$(ls /data/openvpn/*.conf)
            echo "openvpn is not running, starting it with $openvpnConfigFile..."
            $openvpn_script $openvpnConfigFile
        fi
        sleep 1
        checkVpnClients
    fi
    sleep 5
done