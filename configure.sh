#!/bin/bash
# check for cjdns only flag
cjdnsonly=false
if echo "$*" | grep -q -- "--cjdnsonly"; then
  cjdnsonly=true
fi

echo "Enter the port you want to use for CJDNS:"
read CJDNS_PORT
echo $CJDNS_PORT > data/env/port

CONTAINER_NAME="pkt-server"

if [ "$cjdnsonly" = true ]; then
    echo "Starting as CJDNS Node..."
    echo "Enter your secret or leave empty to generate a random one:"
    read secret

    if [ -z "$secret" ]; then
            # Check if .secret file exists
            if [ -f data/env/secret ]; then
                    echo "secret file exists. Reading secret..."
                    secret=$(cat data/env/secret)
            else
                    echo "secret file does not exist. Generating secret..."
                    # Generating random secret
                    secret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
                    echo $secret > data/env/secret
            fi
    fi
    echo "Your secret is: $secret"
    echo "" > data/env/cjdnsonly
else
    rm data/env/cjdnsonly
    echo "Starting as full VPN Server..."
    echo "Provide a name for your VPN Exit"
    echo "VPN Name: "
    read name
    echo "Country of VPN Exit: "
    read country
    echo "Enter your pkt.chat username in order to get direct notifications about changes to your VPN Server:"
    read username
    valid_price=false
    while [[ $valid_price == false ]]; do
        echo "Set price for Premium VPN in PKT (range of 1-100):"
        read price

        # Check if the input is NOT an integer or is not within the range of 1 to 100
        if [[ ! $price =~ ^[0-9]+$ ]] || [[ $price -lt 1 ]] || [[ $price -gt 100 ]]; then
            echo "Invalid input. The price should be an integer within the range of 1 to 100 PKT."
        else
            valid_price=true
        fi
    done
    
    echo $name > data/env/vpnname
    echo $country > data/env/vpncountry
    echo $username > data/env/vpnusername
    echo $price > data/env/vpnprice

    IPERF_PORT=5201
    echo "Running docker container PKT-Server..."
    docker run -d --rm \
            --log-driver 'local' \
            --cap-add=NET_ADMIN \
            --device /dev/net/tun:/dev/net/tun \
            --sysctl net.ipv6.conf.all.disable_ipv6=0 \
            --sysctl net.ipv4.ip_forward=1 \
            -p $CJDNS_PORT:$CJDNS_PORT \
            -p $CJDNS_PORT:$CJDNS_PORT/udp \
            -p $IPERF_PORT:$IPERF_PORT \
            -p $IPERF_PORT:$IPERF_PORT/udp \
            -v ./data:/server/data \
            --name pkt-server pkt-server
fi

# Create run.sh
echo "#!/bin/bash" > run.sh
echo "# Check if the container exists" >> run.sh
echo 'if [[ $(docker ps -a --filter name="'$CONTAINER_NAME'" --format '{{.Names}}') == "'$CONTAINER_NAME'" ]]; then' >> run.sh
echo '  # Container exists, start it' >> run.sh
echo '  docker start '$CONTAINER_NAME >> run.sh
echo '  echo "Container '$CONTAINER_NAME' started."' >> run.sh
echo 'else' >> run.sh
echo 'echo "Running '$CONTAINER_NAME'..."' >> run.sh
echo '  docker run -d -it \' >> run.sh
echo '      --log-driver 'local' \' >> run.sh
echo '      --cap-add=NET_ADMIN \' >> run.sh
echo '      --device /dev/net/tun:/dev/net/tun \' >> run.sh
echo '      --sysctl net.ipv6.conf.all.disable_ipv6=0 \' >> run.sh
echo '      --sysctl net.ipv4.ip_forward=1 \' >> run.sh
echo '      -p '$CJDNS_PORT':'$CJDNS_PORT' \' >> run.sh
echo '      -p '$CJDNS_PORT':'$CJDNS_PORT'/udp \' >> run.sh
if [ "$cjdnsonly" = false ]; then
    echo '      -p '$IPERF_PORT':'$IPERF_PORT' \' >> run.sh
    echo '      -p '$IPERF_PORT':'$IPERF_PORT'/udp \' >> run.sh
fi
echo '      -v ./data:/server/data \' >> run.sh
echo '      --name '$CONTAINER_NAME' '$CONTAINER_NAME'' >> run.sh

chmod +x run.sh