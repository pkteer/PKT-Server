#!/bin/sh
DEVICE="tun0"
cexec="/server/cjdns/contrib/python/cexec"
lsLimitFree=100kbit
lsLimitPaid=950mbit
pkteer_ip="$PKTEER_IP"
pkteer_paid="$PKTEER_PAID"

get_hex_from_ip() {
    decimal_to_hex() {
        printf "%02x" "$1"
    }
    # Extract the last two octets of the source IP address
    last_two_parts=$(echo "$1" | awk -F. '{ print $(NF-1), $NF }')

    part1=$(echo "$last_two_parts" | awk '{print $1}')
    part2=$(echo "$last_two_parts" | awk '{print $2}')

    # Convert each part to hexadecimal
    hex_part1=$(decimal_to_hex "$part1")
    hex_part2=$(decimal_to_hex "$part2")

    # Concatenate the hexadecimal parts
    printf "${hex_part1}${hex_part2}"
}

# Listen for clients
output=$($cexec 'IpTunnel_listConnections()')
output=$(echo "$output" | sed "s/'/\"/g")
#"
conn_ids=$(echo "$output" | jq -r '.connections[]')
if [ -z "$conn_ids" ]; then
    echo "No connections found"
    sleep 2
    continue
fi
# Loop over the connection IDs and extract the IPv4 address for each one
for conn_id in $conn_ids; do
    output=$($cexec 'IpTunnel_showConnection('$conn_id')')
    output=$(echo "$output" | sed "s/'/\"/g")
    ipv4_addr=$(echo "$output" | jq -r '.ip4Address')
    
    echo "Connection $conn_id has IPv4 address $ipv4_addr"
    HEX=$(get_hex_from_ip "$ipv4_addr")

    # Create a tc class for the source IP address
    if [[ "$pkteer_ip" == "$ipv4_addr" ]] && [[ "$pkteer_paid" = "true" ]]; then
        echo "PAID $ipv4_addr"
        tc class replace dev $DEVICE parent 1:fffe classid 1:$HEX hfsc ls m2 $lsLimitPaid ul m2 $lsLimitPaid
        nft add element pfi m_client_leases { $ipv4_addr : "1:$HEX" }
    elif [[ "$pkteer_ip" == "$ipv4_addr" ]] && [[ "$pkteer_paid" = "false" ]]; then
        echo "FREE $ipv4_addr"
        tc class delete dev $DEVICE parent 1:fffe classid 1:$HEX hfsc ls m2 $lsLimitPaid ul m2 $lsLimitPaid
    fi
done