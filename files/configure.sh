#!/bin/bash
no_vpn_flag=false
cjdns_flag=true
with_pktd_flag=false
pktd_passwd=""
pktd_user="x"

# Read the existing config
if [ -f /data/config.json ]; then
    echo "Config file exists. Reading..."
    config_exists=true
else
    echo "Config file does not exist. Creating..."
    cp /server/config.json /data/config.json
fi

json_config=$(cat /data/config.json)

# Compare existing config with new config
# If a field is missing, add it
if $config_exists; then
    new_json_config=$(cat /server/config.json)

    # Get keys from the template and data JSON
    new_keys=$(echo "$new_json_config" | jq -r 'keys[]')
    current_keys=$(echo "$json_config" | jq -r 'keys[]')

    # Loop through template keys and add missing fields to data
    for key in $new_keys; do
        if [[ ! "$current_keys" =~ "$key" ]]; then
            echo "Adding missing field: $key"
            value=$(echo "$new_json_config" | jq -r ".$key")
            json_config=$(echo "$json_config" | jq --arg key "$key" --arg value "$value" '. + {($key): $value}')
        fi
    done
    echo "$json_config" > /data/config.json
fi

pktd_passwd=$(echo "$json_config" | jq -r '.pktd.rpcpass')

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --no-vpn)
      no_vpn_flag=true
      ;;
    --with-pktd)
      with_pktd_flag=true
      ;;
    --pktd-passwd=*)
      with_pktd_flag=true
      pktd_passwd="${arg#*=}"
      ;;
    *)
      
      ;;
  esac
done

# Modify config file according to flags set
if $no_vpn_flag; then
    json_config=$(echo "$json_config" | jq '.cjdns.vpn_exit = false')
else
    json_config=$(echo "$json_config" | jq '.cjdns.vpn_exit = true')
fi
if $with_pktd_flag; then
    json_config=$(echo "$json_config" | jq '.pktd.enabled = true')
else
    json_config=$(echo "$json_config" | jq '.pktd.enabled = false')
fi
if [ -z "$pktd_passwd" ]; then
    pktd_passwd=$(head -c 20 /dev/urandom | md5sum | cut -d ' ' -f1 )
fi
json_config=$(echo "$json_config" | jq --arg pktd_passwd "$pktd_passwd" '.pktd.rpcpass = $pktd_passwd')
json_config=$(echo "$json_config" | jq --arg pktd_user "$pktd_user" '.pktd.rpcuser = $pktd_user')

# Save config file
echo "$json_config" > /data/config.json

# Launching pld
echo "Starting PKT Wallet..."
/server/pktd/bin/pld --pktdir=/data/pktwallet/pkt > /dev/null 2>&1 &
sleep 1
# Check if wallet already exists
if [ -f /data/pktwallet/pkt/wallet.db ]; then
    echo "wallet.db exists. Skipping wallet creation..."
    # unlock wallet
    curl -X POST -H "Content-Type: application/json" -d '{"wallet_passphrase":"password"}' http://localhost:8080/api/v1/wallet/unlock
else
    echo "Creating wallet..."
    /server/create_wallet.sh
    sleep 5
fi

# VPN Server
while [ -z "$PKTEER_SECRET" ]; do
    json=$(curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:8080/api/v1/wallet/getsecret)
    PKTEER_SECRET=$(echo "$json" | jq -r '.secret')
    if [ -z "$PKTEER_SECRET" ]; then
        echo "PKTEER_SECRET is null. The wallet might not be ready yet. Retrying..."
        sleep 5
    fi
done

# Check for existing cjdroute.conf
if [ -f /data/cjdroute.conf ]; then
    echo "Using existing cjdroute.conf."
    if jq empty /data/cjdroute.conf >/dev/null 2>&1; then
        echo "cjdroute.conf is valid JSON"
    else
        echo "cjdroute.conf is not valid JSON. Running --cleanconf..."
        cat /data/cjdroute.conf | /server/cjdns/cjdroute --cleanconf > /data/cjdroute.conf     
    fi
else
    echo "cjdroute.conf does not exist. Generating new cjdroute.conf..."
    /server/cjdns/cjdroute --genconf | /server/cjdns/cjdroute --cleanconf > /server/cjdns/cjdroute.conf 
    mv /server/cjdns/cjdroute.conf /data/cjdroute.conf
    echo "Generating seed..."
    echo "/data/cjdroute.conf|$PKTEER_SECRET" | sha256sum | /server/cjdns/cjdroute --genconf-seed
fi
# change user to cjdns
jq '.security[0].setuser = 0' /data/cjdroute.conf > /data/cjdroute.conf.tmp && mv /data/cjdroute.conf.tmp /data/cjdroute.conf
# set cjdrout.socket path
jq '.pipe = "/server/cjdns/cjdroute.sock"' /data/cjdroute.conf > /data/cjdroute.conf.tmp && mv /data/cjdroute.conf.tmp /data/cjdroute.conf

# Check for existing lnd.conf
if [ -f /data/pktwallet/lnd/lnd.conf ]; then
    echo "Using existing lnd.conf"
else
    echo "lnd.conf does not exist. Copying sample lnd.conf..."
    mkdir /data/pktwallet/lnd
    cp -r /server/pktd/sample-lnd.conf /data/pktwallet/lnd/lnd.conf
fi

cp /server/start.sh /data/start.sh
cp /server/publish_vpn.sh /data/publish_vpn.sh
cp /server/check_running_processes.sh /data/check_running_processes.sh
