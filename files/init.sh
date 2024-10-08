#!/bin/bash
# Check if server has been configured
if [ -f /data/cjdroute.conf ]; then
    echo "Server is configured."
else
    echo "Server has not been configured yet. Exiting..."
    exit
fi

# Create users
useradd cjdns
useradd speedtest

json_config=$(cat /data/config.json)

update_config() {
  local key="$1"
  local value="$2"

  local current_value=$(echo "$json_config" | jq -r ".$key")

  if [ "$current_value" == "null" ]; then
    json_config=$(echo "$json_config" | jq ".$key = $value")
    echo "$json_config" > /data/config.json
  fi
}
update_config "cjdns.enabled" "true"
update_config "cjdns.vpn_exit" "false"
update_config "cjdns.expose_rpc" "false"
update_config "pktd.enabled" "false"
update_config "pktd.public_rpc" "false"
update_config "pktd.cjdns_rpc" "false"
update_config "pktd.rpcuser" "\"x\""
update_config "pktd.rpcpass" "\"\""
update_config "upper_limit_mbit" "1000"

cjdns_flag=$(echo "$json_config" | jq -r '.cjdns.enabled')
vpn_flag=$(echo "$json_config" | jq -r '.cjdns.vpn_exit')
pktd_flag=$(echo "$json_config" | jq -r '.pktd.enabled')
ike_enabled=$(echo "$json_config" | jq -r '.ikev2.enabled')
openvpn_enabled=$(echo "$json_config" | jq -r '.openvpn.enabled')
sniproxy_enabled=$(echo "$json_config" | jq -r '.sniproxy.enabled')

echo "Starting PKT Wallet..."
/server/pktd/bin/pld --pktdir=/data/pktwallet/pkt > /dev/null 2>&1 &
sleep 1

# Check if wallet already exists
if [ -f /data/pktwallet/pkt/wallet.db ]; then
    echo "wallet.db exists. Skipping wallet creation..."
    # unlock wallet
    curl -m 10 -X POST -H "Content-Type: application/json" -d '{"wallet_passphrase":"password"}' http://localhost:8080/api/v1/wallet/unlock
    if [ $? -eq 28 ]; then
        echo "The request timed out, restarting pld"
        killall pld
        /server/pktd/bin/pld --pktdir=/data/pktwallet/pkt > /dev/null 2>&1 &
    fi
fi

if [ "$cjdns_flag" = true ]; then
    mkdir /home/cjdns
    echo "Starting cjdns..."
    # Set CAP_NET_ADMIN to cjdroute
    setcap cap_net_admin=eip /server/cjdns/cjdroute
su - cjdns <<EOF
/server/cjdns/cjdroute < /data/cjdroute.conf &
EOF
sleep 1

else
    echo "cjdns is disabled. Vpn server will not be started."
    vpn_flag=false
fi
echo "pktd enabled: $pktd_flag"
if [ "$pktd_flag" = true ]; then
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

if [ "$cjdns_flag" = true ]; then
    while true; do
        if ifconfig tun0 &> /dev/null; then
            echo "tun0 exists."
            break
        else
            echo "tun0 does not exist. Waiting..."
            sleep 1
        fi
    done
    echo "Setting up iptables rules"
    # Allow cjdns admin access only from eth0
    cjdns_rpc_port=$(cat /data/cjdroute.conf | jq -r '.admin.bind' | cut -d ':' -f2)
    if [ -z "$cjdns_rpc_port" ]; then
            cjdns_rpc_port=$(grep -A 5 "\"admin\":" /data/cjdroute.conf | grep -oP '"bind": "\K[^"]+' | cut -d ':' -f2)
    fi      
    if [[ "$cjdns_rpc_port" =~ ^[0-9]+$ ]]; then
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A INPUT -p udp --dport $cjdns_rpc_port -j REJECT --reject-with icmp-admin-prohibited
    fi
    # TODO:Move to nftables, use pfi_maq.nft
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
    iptables -A FORWARD -i eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1264
    ip route add 10.0.0.0/8 dev tun0
fi

echo "Initializing nftables..."
/server/init_nft.sh

if [ "$vpn_flag" = true ]; then
    echo "Starting vpn server..."
    # Run nodejs anodevpn-server
    if [ -e /data/env/vpnprice ]; then
        export PKTEER_PREMIUM_PRICE=$(cat /data/env/vpnprice)
    else
        # Default price
        export PKTEER_PREMIUM_PRICE=10
    fi
    echo "Starting anodevpn-server at default port 8099..."
    node /server/anodevpn-server/index.js &
    echo "Starting premium_handler..."
    python3 /server/premium_handler.py &
fi

mkdir /home/speedtest
# switch to speedtest user
su - speedtest <<EOF
/server/run_iperf3.sh &
/server/kill_iperf3.sh &
EOF
# switch back to root

echo "Add cjdns peers..."
/server/addCjdnsPeers.sh

# Setup and launch ikev2
echo "IKEv2 enabled: $ike_enabled"
if [ "$ike_enabled" = true ]; then
  /server/vpn_configure.sh
fi

# Setup and launch openvpn
echo "OpenVPN enabled: $openvpn_enabled"
if [ "$openvpn_enabled" = true ]; then
  /server/openvpn_configure.sh
fi
# Start node_exporter for prometheus
/server/node_exporter/node_exporter &

echo "sniproxy enabled: $sniproxy_enabled"
if [ "$sniproxy_enabled" = true ]; then
  /server/start-sni.sh &
fi

# add cronjob for payments once every week
(crontab -l 2>/dev/null; echo "0 0 * * 0 /server/payment.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 */12 * * * /server/addCjdnsPeers.sh") | crontab -
# Start watchdog
if [ "$cjdns_flag" = true ]; then
    /server/watchdog.sh &
fi

# Keep the container alive
tail -f /dev/null
