#!/bin/sh
DEVICE="tun0"
cexec="/server/cjdns/contrib/python/cexec"
lsLimitFree=100kbit
lsLimitPaid=950mbit

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

    # Create a tc class for the source IP address
    echo "Creating tc class for $ipv4_addr"
    if [ "$PAID" = true ]; then
        echo "Give unlimited bandwidth to $ipv4_addr"
        echo "dev $DEVICE parent 1:ffff classid 1:$HEX hfsc ls m2 $lsLimitPaid ul m2 $lsLimitPaid"
        tc class replace dev $DEVICE parent 1:ffff classid 1:$HEX hfsc ls m2 $lsLimitPaid ul m2 $lsLimitPaid
        nft add element pfi m_client_leases { $ipv4_addr : "1:$HEX" }
    else
        tc class delete dev $DEVICE parent 1:ffff classid 1:$HEX hfsc ls m2 $lsLimitPaid ul m2 $lsLimitPaid
        nft delete element pfi m_client_leases { $ipv4_addr : "1:$HEX" }
    fi

    sleep 5
done
