#!/bin/bash
CJDNS_PORT=8099
PKTEER_SECRET="southdragonsea"
CONTAINER_NAME="cjdns"

# Check if the container exists
if [[ $(docker ps -a --filter name="$CONTAINER_NAME" --format '{{.Names}}') == "$CONTAINER_NAME" ]]; then
        # Container exists, start it
        docker start "$CONTAINER_NAME"
        echo "Container $CONTAINER_NAME started."
else
        echo "Running docker container cjdns..."
        docker run -d -it \
                --log-driver 'local' \
                --cap-add=NET_ADMIN \
                --device /dev/net/tun:/dev/net/tun \
                --sysctl net.ipv6.conf.all.disable_ipv6=0 \
                --sysctl net.ipv4.ip_forward=1 \
                -p $CJDNS_PORT:$CJDNS_PORT \
                -p $CJDNS_PORT:$CJDNS_PORT/udp \
                -e "PKTEER_CJDNS_PORT=$CJDNS_PORT" \
                -e "PKTEER_SECRET=$PKTEER_SECRET" \
                --name $CONTAINER_NAME $CONTAINER_NAME

        docker exec $CONTAINER_NAME /server/init_cjdns.sh
fi