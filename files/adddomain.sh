#!/bin/bash

# Get the domain and IPv6 address from command-line arguments
domain=$1
ipv6=$2
sniconffile='/etc/sniproxy.conf'

# Validate the domain
if ! echo "$domain" | grep -Pq "^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$"; then
    echo "Invalid domain"
    exit 1
fi

# Validate the IPv6 address
if ! echo "$ipv6" | grep -Pq "^([a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4}$"; then
    echo "Invalid IPv6 address"
    exit 1
fi

# Check if the domain already exists in the configuration file
if grep -qw "$domain" $sniconffile; then
    # read -p "The domain already exists. Do you want to override it? (y/n) " -n 1 -r
    # echo
    # if [[ $REPLY =~ ^[Yy]$ ]]; then
    # fi
    sed -i "/$domain/c\\\t$domain [$ipv6]:81" $sniconffile
    sed -i "/$domain/c\\\t$domain [$ipv6]:443" $sniconffile
else
    # If the domain doesn't exist, add the domain and IPv6 address to the configuration file
    sed -i "/table http_hosts {/a \\\t$domain [$ipv6]:81" $sniconffile
    sed -i "/table https_hosts {/a \\\t$domain [$ipv6]:443" $sniconffile

    sed -i "/resolver {/a \\\    search $domain" $sniconffile
fi

killall sniproxy
#rm /var/run/proxy.sock
sniproxy