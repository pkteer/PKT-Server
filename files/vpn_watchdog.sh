#!/bin/bash

vpnClientsFile="/server/anodevpn-server/vpnclients.json"
directory="/server/vpnclients/"
duration=$(date -d '1 month ago' +%s%3N)
ipsec_process="/usr/local/libexec/ipsec/pluto"
vpn_script="/server/vpn.sh"
openvpn_script="openvpn --config "

if ! pgrep -f $ipsec_process > /dev/null
then
    echo "$ipsec_process is not running, starting it now..."
    bash $vpn_script
fi

if ! pgrep -f openvpn > /dev/null
then
    openvpnConfigFile=$(ls /data/openvpn/*.conf)
    echo "openvpn is not running, starting it with $openvpnConfigFile..."
    bash $openvpn_script $openvpnConfigFile
fi

size=$(jq '.clients | length' $vpnClientsFile)
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
    else
        echo "$username: Time Created - $timeCreated has not passed the duration $duration"
    fi
done