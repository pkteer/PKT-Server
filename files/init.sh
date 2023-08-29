#!/bin/bash
# Check if server has been configured
if [ -f /data/cjdroute.conf ]; then
    echo "Server is configured."
else
    echo "Server has not been configured yet. Exiting..."
    exit
fi

json_config=$(cat /data/config.json)
cjdns_flag=$(echo "$json_config" | jq -r '.cjdns.enabled')
vpn_flag=$(echo "$json_config" | jq -r '.cjdns.vpn_exit')
pktd_flag=$(echo "$json_config" | jq -r '.pktd.enabled')

echo "Starting PKT Wallet..."
/server/pktd/bin/pld --pktdir=/data/pktwallet/pkt > /dev/null 2>&1 &
sleep 1

# Check if wallet already exists
if [ -f /data/pktwallet/pkt/wallet.db ]; then
    echo "wallet.db exists. Skipping wallet creation..."
    # unlock wallet
    curl -X POST -H "Content-Type: application/json" -d '{"wallet_passphrase":"password"}' http://localhost:8080/api/v1/wallet/unlock
fi

if $cjdns_flag; then
    echo "Starting cjdns..."
    /server/cjdns/cjdroute < /data/cjdroute.conf
else
    echo "cjdns is disabled. Vpn server will not be started."
    vpn_flag=false
fi

if $pktd_flag; then
    rpcuser=$(echo "$json_config" | jq -r '.pktd.rpcuser')
    rpcpass=$(echo "$json_config" | jq -r '.pktd.rpcpass')
    public_rpc=$(echo "$json_config" | jq -r '.pktd.public_rpc')
    cjdns_rpc=$(echo "$json_config" | jq -r '.pktd.cjdns_rpc')

    pktd_cmd="/server/pktd/bin/pktd --homedir=/data/pktd --datadir=/data/pktd/data --logdir=/data/pktd/logs -u $rpcuser -P $rpcpass --maxpeers=2048"
    if $public_rpc; then
        pktd_cmd="$pktd_cmd --rpclisten=0.0.0.0"
    fi
    if $cjdns_rpc; then
        pktd_cmd="$pktd_cmd --rpclisten=::"
    fi
    echo "Launching pktd with command: $pktd_cmd"
    $pktd_cmd > /dev/null 2>&1 &
fi

echo "Setting up iptables rules"
# Allow cjdns admin access only from eth0
cjdns_rpc_port=$(cat /data/cjdroute.conf | jq -r '.admin.bind' | cut -d ':' -f2)
if [ -z "$cjdns_rpc_port" ]; then
        cjdns_rpc_port=$(grep -A 5 "\"admin\":" /data/cjdroute.conf | grep -oP '"bind": "\K[^"]+' | cut -d ':' -f2)
fi      
if [[ "$cjdns_rpc_port" =~ ^[0-9]+$ ]]; then
    iptables -A INPUT -i eth0 -p udp --dport $cjdns_rpc_port -j ACCEPT
    iptables -A INPUT -p udp --dport $cjdns_rpc_port -j DROP
fi
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1264
echo "route add..."
route add -net 10.0.0.0/8 tun0
echo "Initializing nftables..."
/server/init_nft.sh

if $vpn_flag; then
    echo "Starting vpn server..."
    # Run nodejs anodevpn-server
    export PKTEER_PREMIUM_PRICE=$(cat /data/env/vpnprice)
    echo "Starting anodevpn-server at default port 8099..."
    node /server/anodevpn-server/index.js > /dev/null 2>&1 &
    echo "Starting premium_handler..."
    python3 /server/premium_handler.py &
fi

/server/run_iperf3.sh &
/server/kill_iperf3.sh &
/server/node_exporter/node_exporter &

if $cjdns_flag; then
    /server/cjdns_watchdog.sh 
fi
