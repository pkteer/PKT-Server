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

        # If anodevpnserver is running restart it
        if pidof node; then
            echo "anodevpn-server is running, restarting..."
            pkill node
            if [ -e /data/env/vpnprice ]; then
                export PKTEER_PREMIUM_PRICE=$(cat /data/env/vpnprice)
            else
                # Default price
                export PKTEER_PREMIUM_PRICE=10
            fi
            node /server/anodevpn-server/index.js &
        fi
    else
        echo "$(date): cjdns is running."
    fi
    sleep 5
done