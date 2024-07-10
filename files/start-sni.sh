#!/bin/sh
echo "Installing sni proxy..."
dpkg -i /server/sniproxy_0.6.1+git.5.g7fdd86c_amd64.deb

echo "Checking for existing sniproxy.conf..."
if [ -f /data/sniproxy.conf ]; then
    echo "sniproxy.conf already exists, using existing one..."
    cp /data/sniproxy.conf /etc/sniproxy.conf
else
    echo "sniproxy.conf not found, copying default..."
    cp /server/sniproxy.conf /etc/sniproxy.conf
fi

echo "Starting sniproxy..."
sniproxy
