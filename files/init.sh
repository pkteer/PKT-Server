#!/bin/bash
cjdnsonly=false

# check for cjdns only flag
if [ -f /serer/data/env/cjdnsonly ]; then
    cjdnsonly=true
    # Get secret 
    if [ -f /serer/data/env/secret ]; then
        PKTEER_SECRET=$(cat data/env/secret)
    fi
else
    # Launching pld
    ln -s /server/data/pktwallet /root/.pktwallet
    echo "Starting PKT Wallet..."
    /server/pktd/bin/pld > /dev/null 2>&1 &
    sleep 1
    # Check if wallet already exists
    if [ -f /server/data/.pktwallet/wallet.db ]; then
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
fi
# Get port
if [ -f /serer/data/env/port ]; then
    CJDNS_PORT=$(cat data/env/port)
fi

# Check for existing cjdroute.conf
if [ -f /server/data/cjdroute.conf ]; then
    echo "Using existing cjdroute.conf."
else
    echo "cjdroute.conf does not exist. Generating new cjdroute.conf..."
    /server/cjdns/cjdroute --genconf | /server/cjdns/cjdroute --cleanconf > cjdroute.conf | jq '.interfaces.UDPInterface[0].bind = "0.0.0.0:'"$CJDNS_PORT"'"' cjdroute.conf | sponge cjdroute.conf
    sed -i 's/"setuser": "nobody"/"setuser": 0/' /server/cjdns/cjdroute.conf
    mv /server/cjdns/cjdroute.conf /server/data/cjdroute.conf
fi

echo "Starting cjdns..."
/server/cjdns/cjdroute < /server/data/cjdroute.conf
echo "Generating seed..."
echo "/server/data/cjdroute.conf|$PKTEER_SECRET" | sha256sum | /server/cjdns/cjdroute --genconf-seed

# Run watchdog
/server/cjdns_watchdog.sh

# Initialize server for VPN Node
if [ "$cjdnsonly" = false ]; then
    echo "Setting up iptables rules"
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
    iptables -A FORWARD -i eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1264
    echo "route add..."
    route add -net 10.0.0.0/8 tun0
    echo "Initializing nftables..."
    ./init_nft.sh
    # Run nodejs anodevpn-server
    echo "Starting anodevpn-server..."
    node /server/anodevpn-server/index.js &

    /server/vpn_info.sh
    python3 /server/premium_handler.py &
    /server/run_iperf3.sh &
    /server/kill_iperf3.sh &
fi

