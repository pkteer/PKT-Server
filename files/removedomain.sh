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
    # If the domain exists, remove the domain and IPv6 address from the configuration file
    sed -i "/\t$domain \[$ipv6\]:80/d" $sniconffile
    sed -i "/\t$domain \[$ipv6\]:443/d" $sniconffile
    
    sed -i "/search $domain/d" $sniconffile

    killall sniproxy
    rm /var/run/proxy.sock
    sniproxy
fi

