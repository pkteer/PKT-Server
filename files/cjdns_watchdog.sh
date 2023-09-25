#!/bin/bash
while true; do
    # use timeout in case cjdroute is not running
    if ! timeout 2s /server/cjdns/tools/cexec 'ping()' | grep -q pong; then
        echo "cjdns is not running, restarting..."
        pkill cjdroute
        if pidof cjdroute > /dev/null; then
            pkill -9 cjdroute
        fi
        # Set CAP_NET_ADMIN to cjdroute
        setcap cap_net_admin=eip /server/cjdns/cjdroute
        # Launch cjdns
su - cjdns <<EOF
/server/cjdns/cjdroute < /data/cjdroute.conf

EOF
        # kill anodevpn-server, so it restarts
        kill $(ps aux | pgrep -x node)
        
    else
        echo "$(date): cjdns is running."
    fi
    sleep 2
    # Check that anodevpn-server is running
    node=$(ps aux | pgrep -x node)
    if [ -z "$node" ]; then
        echo "anodevpn-server is not running, restarting..."
        if [ -e /data/env/vpnprice ]; then
            export PKTEER_PREMIUM_PRICE=$(cat /data/env/vpnprice)
        else
            # Default price
            export PKTEER_PREMIUM_PRICE=10
        fi
        node /server/anodevpn-server/index.js &
    else
        response=$(curl --write-out %{http_code} --silent --connect-timeout 5 --output /dev/null http://localhost:8099)
        if [ "$response" -eq 404 ]; then
            echo "$(date): anodevpn-server is running."
        else
            echo "anodevpn-server is running but not responding, restarting..."
            kill $(ps aux | pgrep -x node)
        fi
    fi
    sleep 5
done