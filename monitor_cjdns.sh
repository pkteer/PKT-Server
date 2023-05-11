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
        tc class add dev $DEVICE parent 1:1 classid 1:$HEX hfsc ls m2 $lsLimitPaid
    else
        tc class add dev $DEVICE parent 1:1 classid 1:$HEX hfsc ls m2 $lsLimitFree
    fi
    tc qdisc add dev $DEVICE parent 1:$HEX handle $HEX: cake

    sleep 2
done

# Delete anything which already exists
# tc qdisc add dev tun0 root handle 1:0 hfsc default ffff
#   tc class add dev br-br parent 1:0 classid 1:1 hfsc ls m2 100mbit ul m2 100mbit
#     tc class add dev br-br parent 1:1 classid 1:11 hfsc ls m2 1kbit # 1:11 = mining
#       tc qdisc add dev br-br parent 1:11 handle 11: fq_codel noecn # Don't spend too much CPU on this
#     tc class add dev br-br parent 1:1 classid 1:12 hfsc ls m2 100kbit # 1:12 = cjdns
#     tc class add dev br-br parent 1:1 classid 1:f254 hfsc ls m2 100kbit # 1:f254 = management
#       tc qdisc add dev br-br parent 1:ffff handle ffff: cake
#   tc class add dev br-br parent 1:0 classid 1:2 hfsc ls m2 100mbit # speedtest, no upper limit O_O