#!/bin/sh
echo "Installing required packages..."
apt-get install autotools-dev cdbs debhelper dh-autoreconf dpkg-dev gettext libev-dev libpcre2-dev libudns-dev pkg-config fakeroot devscripts

echo "Installing sni proxy..."
dpkg -i /server/sniproxy_0.6.1+git.5.g7fdd86c_amd64.deb

echo "Copying sniproxy.conf..."
cp /server/sniproxy.conf /etc/sniproxy.conf

echo "Starting sniproxy..."
sniproxy
