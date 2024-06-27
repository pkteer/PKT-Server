#!/bin/bash
restart() {
    # Kill cjdroute
    pkill cjdroute
    if pidof cjdroute > /dev/null; then
        pkill -9 cjdroute
    fi

    # Kill node
    kill $(ps aux | pgrep -x node)

    # Set CAP_NET_ADMIN to cjdroute
    setcap cap_net_admin=eip /server/cjdns/cjdroute

    # Launch cjdns
su - cjdns <<EOF
/server/cjdns/cjdroute < /data/cjdroute.conf

EOF

    # Launch node
    if [ -e /data/env/vpnprice ]; then
        export PKTEER_PREMIUM_PRICE=$(cat /data/env/vpnprice)
    else
        # Default price
        export PKTEER_PREMIUM_PRICE=10
    fi
    node /server/anodevpn-server/index.js &

    sleep 2
    # Add route
    ip route add 10.0.0.0/8 dev tun0
}

while true; do
    # use timeout in case cjdroute is not running
    cjdroute=$(ps aux | pgrep -x cjdroute)
    if [ -z "$cjdroute" ]; then
        echo "cjdns is not running, restarting..."
        restart
    else
        echo "$(date): cjdns is running."
    fi
    sleep 2
    # Check that anodevpn-server is running
    node=$(ps aux | pgrep -x node)
    if [ -z "$node" ]; then
        echo "anodevpn-server is not running, restarting..."
        restart
    else
        response=$(curl --write-out %{http_code} --silent --connect-timeout 5 --output /dev/null http://localhost:8099/healthcheck)
        if [ "$response" -eq 200 ]; then
            echo "$(date): anodevpn-server is running."
        else
            echo "anodevpn-server is running but not responding, restarting..."
            restart
        fi
    fi
    sleep 5
    # Run vpn_watchdog
    /server/vpn_watchdog.sh
    sleep 1
done