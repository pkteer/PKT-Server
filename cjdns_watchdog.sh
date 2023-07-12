#!/bin/bash
while true; do
    output=$(/server/cjdns/contrib/python/cexec 'ping()')
    sleep 1
    if [ -z "$output" ]; then
        echo "cjdns is not running, restarting..."
        # Get the cjdroute PID
        pid=$(pidof cjdroute)
        if [[ -n $pid && $pid =~ ^[0-9]+$ ]]; then
            kill "$pid"
            sleep 1
            # Check if cjdroute is still alive
            if ps -p "$pid" > /dev/null; then
                echo "cjdroute is still running"
                # Force kill cjdroute with -9 signal
                kill -9 "$pid"
            fi
        fi
        # Launch cjdns
        /server/cjdns/cjdroute < /server/cjdns/cjdroute.conf
        # If anodevpnserver is running restart it
        nodepid=$(pidof node)
        if [[ -n $nodepid && $nodepid =~ ^[0-9]+$ ]]; then
            kill "$nodepid"
            node /server/anodevpn-server/index.js &
        fi
    else
        echo "cjdns is running."
    fi
    sleep 5
done