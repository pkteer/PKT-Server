#!/bin/sh

echo "Getting ipsec-vpn install script..."
wget https://get.vpnsetup.net -O vpn.sh 
chmod +x /server/vpn.sh

echo "Configuring VPN credentials..."
CONFIG_FILE="/data/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found, proceeding with default values."
else
    VPN_USERNAME=$(jq -r '.vpnclient.username' $CONFIG_FILE)
    VPN_PASSWORD=$(jq -r '.vpnclient.password' $CONFIG_FILE)
    VPN_SHARED_KEY=$(jq -r '.vpnclient.sharedKey' $CONFIG_FILE)
    if [ -z "$VPN_USERNAME" ] || [ -z "$VPN_PASSWORD" ] || [ -z "$VPN_SHARED_KEY" ]; then
        echo "One or more required values not found in config file, proceeding with default values."
    else
        sed -i "s/YOUR_IPSEC_PSK=''/YOUR_IPSEC_PSK='$VPN_SHARED_KEY'/g" vpn.sh
        sed -i "s/YOUR_USERNAME=''/YOUR_USERNAME='$VPN_USERNAME'/g" vpn.sh
        sed -i "s/YOUR_PASSWORD=''/YOUR_PASSWORD='$VPN_PASSWORD'/g" vpn.sh
    fi
fi

echo "Starting VPN setup..."
/server/vpn.sh

# Copy new ikev2 conf file
cp /server/ikev2.conf /etc/ipsec.d/ikev2.conf
# Restart ipsec
service ipsec restart
# Run nat66 script
nft -f /server/nat66.nft

echo "Exporting VPN client files..."
cp /root/vpnclient.* /data/
