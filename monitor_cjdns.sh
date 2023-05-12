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
    if [ -z "$conn_ids" ]; then
        echo "connections array is empty"
        exit 1
    fi
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
    echo "Creating tc class for $ipv4_addr"
    if [ "$paid" = false ]; then
        echo "Give limited bandwidth to $ipv4_addr"
        tc class replace dev $DEVICE parent 1:fffe classid 1:$HEX hfsc ls m2 $lsLimitPaid ul m2 $lsLimitPaid
    else
        echo "Give unlimited bandwidth to $ipv4_addr"
        tc class replace dev $DEVICE parent 1:fffe classid 1:$HEX hfsc ls m2 $lsLimitFree 
    fi
    tc qdisc replace dev $DEVICE parent 1:$HEX handle $HEX: cake

    sleep 30
done
