#!/bin/bash

echo "Generating seed..."
echo "/server/cjdns/cjdroute.conf|$PKTEER_SECRET" | sha256sum | /server/cjdns/cjdroute --genconf-seed

echo "Starting cjdns..."
sed -i 's/"setuser": "nobody"/"setuser": 0/' /server/cjdns/cjdroute.conf
/server/cjdns/cjdroute < /server/cjdns/cjdroute.conf