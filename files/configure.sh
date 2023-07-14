#!/bin/bash
if [ -f /data/env/port ]; then
    CJDNS_PORT=$(cat /data/env/port)
else 
    echo "Enter server's port:"
    read CJDNS_PORT
    mkdir /data/env
    echo $CJDNS_PORT > /data/env/port
fi
# Launching pld
echo "Starting PKT Wallet..."
/server/pktd/bin/pld --pktdir=/data/pktwallet/pkt > /dev/null 2>&1 &
sleep 1
# Check if wallet already exists
if [ -f /data/pktwallet/pkt/wallet.db ]; then
    echo "wallet.db exists. Skipping wallet creation..."
    # unlock wallet
    curl -X POST -H "Content-Type: application/json" -d '{"wallet_passphrase":"password"}' http://localhost:8080/api/v1/wallet/unlock
else
    echo "Creating wallet..."
    /server/create_wallet.sh
fi
# VPN Server
while [ -z "$PKTEER_SECRET" ]; do
    json=$(curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:8080/api/v1/wallet/getsecret)
    PKTEER_SECRET=$(echo "$json" | jq -r '.secret')
    if [ -z "$PKTEER_SECRET" ]; then
        echo "PKTEER_SECRET is null. Retrying..."
    fi
done

# Check for existing cjdroute.conf
if [ -f /data/cjdroute.conf ]; then
    echo "Using existing cjdroute.conf."
else
    echo "cjdroute.conf does not exist. Generating new cjdroute.conf..."
    /server/cjdns/cjdroute --genconf | /server/cjdns/cjdroute --cleanconf > /data/cjdroute.conf | jq '.interfaces.UDPInterface[0].bind = "0.0.0.0:'"$CJDNS_PORT"'"' cjdroute.conf | sponge cjdroute.conf
    sed -i 's/"setuser": "nobody"/"setuser": 0/' /server/cjdns/cjdroute.conf
    mv /server/cjdns/cjdroute.conf /data/cjdroute.conf
    echo "Generating seed..."
    echo "/data/cjdroute.conf|$PKTEER_SECRET" | sha256sum | /server/cjdns/cjdroute --genconf-seed
fi
