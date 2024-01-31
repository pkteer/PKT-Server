#!/bin/sh
die() {
        echo "Error: $1"
        exit 100
}
command -v docker > /dev/null || die "docker is required to run this program"

docker run -it --rm \
        --log-driver 'local' \
        --cap-add=ALL \
        --device /dev/net/tun:/dev/net/tun \
	    --network host \
        -v $(pwd):/data \
        --name pkt-server-reversevpn \
        pkt-server-reversevpn