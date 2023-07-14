#!/bin/bash
while true; do
    # use timeout in case cjdroute is not running
    if ! timeout 2s /server/cjdns/tools/cexec 'ping()' | grep -q pong; then
        echo "cjdns is not running, restarting..."
        pkill cjdroute
        if pidof cjdroute > /dev/null; then
            pkill -9 cjdroute
        fi
        # Launch cjdns
        /server/cjdns/cjdroute < /server/cjdns/cjdroute.conf
        # If anodevpnserver is running restart it
        if pidof node; then
            echo "anodevpn-server is running, restarting..."
            pkill node
            node /server/anodevpn-server/index.js &
        fi
    else
        echo "$(date): cjdns is running."
    fi
    sleep 5
done