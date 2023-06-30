#!/bin/bash
echo "Provide the port to use for cjdns:"
read port

echo "Building cjdns docker image..."
docker build --build-arg CJDNS_PORT=$port -t cjdns -f Dockerfile.cjdns .