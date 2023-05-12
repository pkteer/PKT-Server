#!/bin/sh
paid=false
DEVICE="tun0"
cexec="/server/cjdns/contrib/python/cexec"
lsLimitFree=100kbit
lsLimitPaid=100mbit

# Listen for clients
while true; do
    output=$($cexec 'IpTunnel_listConnections()')
    output=$(echo "$output" | sed "s/'/\"/g")
    #"
    conn_ids=$(echo "$output" | jq -r '.connections[]')
    
    # Loop over the connection IDs and extract the IPv4 address for each one
    for conn_id in $conn_ids; do
        output=$($cexec 'IpTunnel_showConnection('$conn_id')')
        output=$(echo "$output" | sed "s/'/\"/g")
        ipv4_addr=$(echo "$output" | jq -r '.ip4Address')
        echo "Connection $conn_id has IPv4 address $ipv4_addr"
    done

    # Extract the last two octets of the source IP address
    OCTETS=$(echo "$ipv4_addr" | awk -F '.' '{print $3 $4}')

    # Convert the octets to hex
    HEX=$(printf '%02x' $OCTETS)
    
    # remove all existing entries
    #tc qdisc del dev $DEVICE root

    # Create a tc class for the source IP address
    if [ "$paid" = true ]; then
        tc class add dev $DEVICE parent 1:1 classid 1:$HEX hfsc ls m2 $lsLimitPaid ul m2 $lsLimitPaid
    else
        tc class add dev $DEVICE parent 1:1 classid 1:$HEX hfsc ls m2 $lsLimitFree m2 $lsLimitFree
    fi
    tc qdisc add dev $DEVICE parent 1:$HEX handle $HEX: cake

    sleep 2
done
