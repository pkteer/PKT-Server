#!/bin/bash
lnd_node_pubkey="028284de0531d97630876e38e087dde543bed8397d4479048ae9b4ccd627d93422"
lnd_node_address="162.19.94.228:9736"
# Create PKT address if none exist
echo "Checking for PKT address..."
addresses=$(/server/pktd/bin/pldctl wallet/address/balances --showzerobalance)
if  echo $addresses | jq -e '.addrs | length == 0' > /dev/null; then
    echo "Creating PKT address..."
    /server/pktd/bin/pldctl wallet/address/create | jq -r '.address' > /data/pktwallet/pkt/addresses.txt
else 
    echo "$addresses" | jq -r '.addrs[].address' > /data/pktwallet/pkt/addresses.txt
fi
echo "PKT address(es): $(cat /data/pktwallet/pkt/addresses.txt)"

# Checking for lnd peers
echo "Checking for lightning peers..."
response=$(/server/pktd/bin/pldctl lightning/peer)

# Check if the response contains "ERROR"
if [[ $response == *"ERROR"* ]]; then
    echo "ERROR: Retrying..."
    sleep 5 # Wait for 5 seconds before retrying
    response=$(/server/pktd/bin/pldctl lightning/peer)
fi

# Check if the response is empty
if [[ -z "$response" || $(echo "$response" | jq -r '.peers') == "[]" ]]; then
    # Run curl command
    echo "No lightning peers found. Connecting to PKT lnd peer..."
    peer_connect_response=$(/server/pktd/bin/pldctl lightning/peer/connect --addr.pubkey=$lnd_node_pubkey --addr.host=$lnd_node_address)

    # Check the output of curl command
    if [[ $(echo "$peer_connect_response" | jq -r '.') == "{}" ]]; then
        echo "Connected to PKT lnd peer successfully."
    elif [[ $(echo "$peer_connect_response" | jq -r '.message') == "ErrServerNotActive: server is still in the process of starting" ]]; then
        error_message=$(echo "$peer_connect_response" | jq -r .message)
        echo "Error: $error_message"
    else
        echo "Unexpected response from curl command: $peer_connect_response"
    fi
else
    echo "Unexpected response from initial command: $response"
fi