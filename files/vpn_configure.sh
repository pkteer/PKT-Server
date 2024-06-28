#!/bin/sh

echo "Getting ipsec-vpn install script..."
wget https://get.vpnsetup.net -O vpn.sh 
chmod +x /server/vpn.sh

echo "Configuring VPN credentials..."
CONFIG_FILE="/data/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found, proceeding with default values."
else
    ikevpnclient=$(jq -r '.ikevpnclient.enabled' $CONFIG_FILE)
    if [ "$ikevpnclient" = "true" ]; then
        VPN_USERNAME=$(jq -r '.ikevpnclient.username' $CONFIG_FILE)
        VPN_PASSWORD=$(jq -r '.ikevpnclient.password' $CONFIG_FILE)
        VPN_SHARED_KEY=$(jq -r '.ikevpnclient.sharedKey' $CONFIG_FILE)
        if [ -z "$VPN_USERNAME" ] || [ -z "$VPN_PASSWORD" ] || [ -z "$VPN_SHARED_KEY" ]; then
            echo "One or more required values not found in config file, proceeding with default values."
        else
            sed -i "s/YOUR_IPSEC_PSK=''/YOUR_IPSEC_PSK='$VPN_SHARED_KEY'/g" vpn.sh
            sed -i "s/YOUR_USERNAME=''/YOUR_USERNAME='$VPN_USERNAME'/g" vpn.sh
            sed -i "s/YOUR_PASSWORD=''/YOUR_PASSWORD='$VPN_PASSWORD'/g" vpn.sh
        fi
    fi
fi

echo "Starting VPN setup..."
/server/vpn.sh

# create directory for vpnclient files
mkdir -p /server/vpnclients
# edit ikev2 conf file
publicIpv4=$(curl -s https://api.ipify.org)
cjdnsIpv6=$(cat /data/cjdroute.conf | jq -r '.ipv6' | cut -d: -f1-4)
sed -i "s/={{PUBLIC_IPv4}}/=$publicIpv4/g" /server/ikev2.conf
sed -i "s/{{CJDNS_IPV6}}/$cjdnsIpv6/g" /server/ikev2.conf
# Copy new ikev2 conf file
cp /server/ikev2.conf /etc/ipsec.d/ikev2.conf
# Restart ipsec
ipsec restart
echo "Exporting VPN client files..."
ikev2.sh --exportclient vpnclient
cp /root/vpnclient.* /data/

echo "Remove drop rule from nft"
rule_pattern='^(\s+)?counter packets [0-9]+ bytes [0-9]+ drop(\s+)?#'
rules=$(nft -a list chain ip filter FORWARD)
handle=$(echo "$rules" | grep -E "$rule_pattern" | awk '{print $NF}')
if [ -z "$handle" ]; then
  echo "Rule not found"
  exit 1
fi
nft delete rule ip filter FORWARD handle $handle
echo "Rule with handle $handle removed"

# Run nat66 script
nft -f /server/nat66.nft

sysctl -w net.ipv6.conf.all.forwarding=1
# Remove ip nat table from nft
nft delete table ip nat

