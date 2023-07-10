#!/bin/bash

echo "Building cjdns docker image..."
docker build --build-arg CJDNS_PORT=8099 -t cjdns -f Dockerfile.cjdns .