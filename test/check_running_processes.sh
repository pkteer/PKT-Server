#!/bin/bash
die() {
        echo "Error: $1"
        exit 100
}
command -v jq > /dev/null || die "jq is required to run this program"
command -v dirname > /dev/null || die "dirname is required to run this program"
command -v docker > /dev/null || die "docker is required to run this program"
cd $(dirname "$0")

# Check that config.json exists
if [ ! -f config.json ]; then
    echo "TEST FAILED: config.json does not exist"
    exit 1
fi
# Print out the values set at config.json
json_config=$(cat config.json)
cjdns_flag=$(echo "$json_config" | jq -r '.cjdns.enabled')
echo "Cjdns Enabled: $cjdns_flag"
vpn_flag=$(echo "$json_config" | jq -r '.cjdns.vpn_exit')
echo "VPN Exit: $vpn_flag"
cjdns_rpc=$(echo "$json_config" | jq -r '.cjdns.expose_rpc')
echo "Expose Cjdns RPC: $cjdns_rpc"
pktd_flag=$(echo "$json_config" | jq -r '.pktd.enabled')
echo "PKTD Enabled: $pktd_flag"
pktd_public_rpc=$(echo "$json_config" | jq -r '.pktd.public_rpc')
echo "PKTD Public RPC: $pktd_public_rpc"
pktd_cjdns_rpc=$(echo "$json_config" | jq -r '.pktd.cjdns_rpc')
echo "PKTD Cjdns RPC: $pktd_cjdns_rpc"
pktd_user=$(echo "$json_config" | jq -r '.pktd.rpcuser')
echo "PKTD User: $pktd_user"
pktd_passwd=$(echo "$json_config" | jq -r '.pktd.rpcpass')
echo "PKTD Password: $pktd_passwd"
upper_limit=$(echo "$json_config" | jq -r '.upper_limit_mbit')
echo "Bandwidth Upper Limit: $upper_limit"

# Check that cjdroute.conf exists
if [ ! -f cjdroute.conf ]; then
    echo "TEST FAILED: cjdroute.conf does not exist"
    exit 1
fi
# Check for values at cjdroute.conf
cjdns_ipv6=$(cat cjdroute.conf | jq -r '.ipv6')
echo "Cjdns IPv6: $cjdns_ipv6"
cjdns_publickey=$(cat cjdroute.conf | jq -r '.publicKey')
echo "Cjdns Public Key: $cjdns_publickey"
cjdns_port=$(cat cjdroute.conf | jq -r '.interfaces.UDPInterface[0].bind' | sed 's/^.*://')
echo "Cjdns Port: $cjdns_port"
cjdns_rpc_port=$(cat cjdroute.conf | jq -r '.admin.bind' | cut -d ':' -f2)
echo "Cjdns RPC Port: $cjdns_rpc_port"
cjdns_user=$(cat cjdroute.conf | jq -r '.security[0].setuser')
echo "Cjdns User: $cjdns_user"

# Get container name of pkt-server:latest
container=$(docker ps --filter "ancestor=pkt-server" --format "{{.Names}}")

# Check that cjdns is running
cjdns=$(docker exec -it $container bash -c "ps -aux | pgrep cjdroute")
if [ -z "$cjdns" ]; then
    echo "TEST FAILED: cjdns is not running"
    exit 1
else
    echo "Cjdns is running"
fi

# Check that pld is running
pld=$(docker exec -it $container bash -c "ps -aux | pgrep pld")
if [ -z "$pld" ]; then
    echo "TEST FAILED: pld is not running"
    exit 1
else
    echo "PLD is running"
fi

# Check that anodevpn-server is running
anodevpn=$(docker exec -it $container bash -c "ps aux | pgrep -x node")
if [ -z "$anodevpn" ]; then
    echo "TEST FAILED: anodevpn-server is not running"
    exit 1
fi

# Check that pktd is running, if pktd is enabled
if $pktd_flag; then
    pktd=$(docker exec -it $container bash -c "ps aux | pgrep pktd")
    if [ -z "$pktd" ]; then
        echo "TEST FAILED: pktd is not running"
        exit 1
    fi
fi

# Check that node_exporter is running
nodeexporter=$(docker exec -it $container bash -c "ps aux | pgrep -x node_exporter")
if [ -z "$nodeexporter" ]; then
    echo "TEST FAILED: node exporter is not running"
    exit 1
fi

# Check that cjdns_watchdog is running
cjdns_watchdog=$(docker exec -it $container bash -c "ps aux | pgrep -x cjdns_watchdog.")
if [ -z "$cjdns_watchdog" ]; then
    echo "TEST FAILED: cjdns_watchdog is not running"
    exit 1
fi

# Check IPTABLES
echo "Display iptables rules..."
docker exec -it $container bash -c "iptables -t nat -L"
echo "Show routes..."
docker exec -it $container bash -c "ip route show"

# Print out rules for eth0 and tun0
echo "Display tc rules for eth0"
docker exec -it $container bash -c "tc class show dev eth0"
echo "Display tc rules for tun0"
docker exec -it $container bash -c "tc class show dev tun0"

echo "TEST PASSED"

sleep 1

echo "Killing cjdns, it should restart automatically..."
docker exec -it $container bash -c "pkill cjdroute"
sleep 12
# Check that cjdns is running
cjdns=$(docker exec -it $container bash -c "ps -aux | pgrep cjdroute")
if [ -z "$cjdns" ]; then
    echo "TEST FAILED: cjdns is not running"
    exit 1
else
    echo "Cjdns is running"
fi

echo "Killing anodevpn-server, it should restart automatically..."
docker exec -it $container bash -c "pkill node"
sleep 12
# Check that cjdns is running
cjdns=$(docker exec -it $container bash -c "ps -aux | pgrep -x node")
if [ -z "$cjdns" ]; then
    echo "TEST FAILED: anodevpn is not running"
    exit 1
else
    echo "anodevpn is running"
fi