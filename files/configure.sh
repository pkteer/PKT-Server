#!/bin/bash
no_vpn_flag=false
cjdns_flag=true
with_pktd_flag=false
pktd_passwd=""
pktd_user="x"

# Read the existing config
json_config=$(cat /data/config.json)
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
if $with_pktd_flag && [ -z "$pktd_passwd" ]; then
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
fi
# VPN Server
while [ -z "$PKTEER_SECRET" ]; do
    json=$(curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:8080/api/v1/wallet/getsecret)
    PKTEER_SECRET=$(echo "$json" | jq -r '.secret')
    if [ -z "$PKTEER_SECRET" ]; then
        echo "PKTEER_SECRET is null. Retrying..."
    fi
done

# Check for existing cjdroute.conf
if [ -f /data/cjdroute.conf ]; then
    echo "Using existing cjdroute.conf."
else
    echo "cjdroute.conf does not exist. Generating new cjdroute.conf..."
    /server/cjdns/cjdroute --genconf | /server/cjdns/cjdroute --cleanconf > /server/cjdns/cjdroute.conf 
    sed -i 's/"setuser": "nobody"/"setuser": 0/' /server/cjdns/cjdroute.conf
    mv /server/cjdns/cjdroute.conf /data/cjdroute.conf
    echo "Generating seed..."
    echo "/data/cjdroute.conf|$PKTEER_SECRET" | sha256sum | /server/cjdns/cjdroute --genconf-seed
fi

cp /server/config.json /data/config.json
cp /server/start.sh /data/start.sh
cp /server/publish_vpn.sh /data/publish_vpn.sh
