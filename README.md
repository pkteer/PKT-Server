# PKT-Server

This should help you to easily set up an Anode VPN Exit using cjdns.


## Set up your own VPN Exit

1. Create a data directory where the server configuration will be stored.

```mkdir data```

2. Configure the server by running the following command:

```docker run -it --rm -v $(pwd)/data:/data dimitris2023/pkt-server /configure.sh```

It will ask you for which port to use, select a port that is not used by any other service on your machine and that is publicly accessible, use port forwarding if necessary.

The configure process will create:
* a cjdroute.conf at data/cjdroute.conf
* PKT wallet at data/pktwallet/pkt/wallet.db
* store the wallet's seed phrase at data/pktwallet/pkt/seed.txt
**NOTE**: Make sure to safely store your seed phrase in order to be able to import your wallet on your computer. And delete the seed.txt file after.

3. Run the server by running the following commands:

```CJDNS_PORT=$(cat ./data/env/port)```
```
docker run -it --rm \
           --log-driver 'local' \
           --cap-add=NET_ADMIN \
           --device /dev/net/tun:/dev/net/tun \
           --sysctl net.ipv6.conf.all.disable_ipv6=0 \
           --sysctl net.ipv4.ip_forward=1 \
           -p $CJDNS_PORT:$CJDNS_PORT \
           -p $CJDNS_PORT:$CJDNS_PORT/udp \
           -p $5281:$5281 \
           -p $5281:$5281/udp \
           -v $(pwd)/data:/data \
           dimitris2023/pkt-server
```

4. Publish your VPN Server

To publish the VPN Server and make it accessible to others you can run do:

```wget https://raw.githubusercontent.com/pkteer/PKT-Server/main/vpn_info.sh```

```chmod +x vpn_info.sh```

```./vpn_info.sh```

This will ask you to set a name for your server, the country where it is running and a price in PKT (10-100) for Premium VPN access.
The details will be published and your VPN Server will be ready to use.
