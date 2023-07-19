#!/bin/bash
# Check if server has been configured
if [ -f /data/cjdroute.conf ]; then
    echo "Server is configured."
else
    echo "Server has not been configured yet. Exiting..."
    exit
fi
echo "Starting PKT Wallet..."
/server/pktd/bin/pld --pktdir=/data/pktwallet/pkt > /dev/null 2>&1 &
sleep 1
# Check if wallet already exists
if [ -f /data/pktwallet/pkt/wallet.db ]; then
    echo "wallet.db exists. Skipping wallet creation..."
    # unlock wallet
    curl -X POST -H "Content-Type: application/json" -d '{"wallet_passphrase":"password"}' http://localhost:8080/api/v1/wallet/unlock
fi

echo "Starting cjdns..."
/server/cjdns/cjdroute < /data/cjdroute.conf

echo "Setting up iptables rules"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1264
echo "route add..."
route add -net 10.0.0.0/8 tun0
echo "Initializing nftables..."
/server/init_nft.sh

# Run nodejs anodevpn-server
export ANODE_SERVER_PORT=$(cat /data/env/port)
export PKTEER_PREMIUM_PRICE=$(cat /data/env/vpnprice)
echo "Starting anodevpn-server with port $ANODE_SERVER_PORT"
node /server/anodevpn-server/index.js &
echo "Starting premium_handler..."
python3 /server/premium_handler.py &
/server/run_iperf3.sh &
/server/kill_iperf3.sh &

/server/cjdns_watchdog.sh 
