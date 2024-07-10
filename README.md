# PKT-Server

The PKT-Server is a docker image that can be used to set up a server that can be used to host a PKT wallet, a CJDNS VPN Exit, an AnodeVPN server, an IKEv2 VPN server and an OpenVPN server.
In the first case a user can connect to the VPN exit using cjdns and then access the internet through cjdns and your server. 
On the second case the user can also use IKEv2 and OpenVPN to connect to the server and access the internet through it without the need to run cjdns on their computer but they will get access to the cjdns network.

You can follow the first set of instractions for setting up a CJDNS only VPN Exit or the second set of instructions for setting up the server with an IKEv2 and OpenVPN server.

## Set up your own CJDNS VPN Exit

1. Create a data directory where the server configuration will be stored.

```mkdir vpn_data```

2. Configure the server by running the following command:

```docker run -it --rm -v $(pwd)/vpn_data:/data pkteer/pkt-server /configure.sh```

It will ask you for which port to use, select a port that is not used by any other service on your machine and that is publicly accessible, use port forwarding if necessary.

The configure process will create:
* a cjdroute.conf at data/cjdroute.conf
* PKT wallet at data/pktwallet/pkt/wallet.db
* store the wallet's seed phrase at data/pktwallet/pkt/seed.txt

configure.sh can take the following flags:
* --no-vpn: To configure the server without setting up the VPN server
* --with-pktd: To configure the server with a local PKT daemon
* --pktd-passwd= : To set a password for the PKT daemon

Alternativly you can edit the config.json file manually.

**NOTE**: Make sure to safely store your seed phrase in order to be able to import your wallet on your computer. And delete the seed.txt file after.

3. Run the server by running the following commands:

```./vpn_data/start.sh```

This will start the server and may expose the following ports:
* cjdns port set from cjdroute.conf
* cjdns admin rpc port set from cjdroute.conf (default 11234)
* 8099 for anodevpn server
* 5201 for iperf3
* 64764 for pktd

4. Publish your VPN Server

To publish the VPN Server and make it accessible to others you can run:

```./vpn_data/publish_vpn.sh```

This will ask you to set a name for your server, the country where it is running and a price in PKT (10-100) for Premium VPN access.
The details will be published and your VPN Server will be ready to use.

## Set up your own VPN Exit with IKEv2 and OpenVPN servers

1. Create a data directory where the server configuration will be stored.

```mkdir vpn_data```

2. Configure the server by running the following command:

```docker run -it --rm -v $(pwd)/vpn_data:/data pkteer/pkt-server /configure.sh```

3. Configure various service by running the following command:

```./vpn_data/setup.sh```

The script will prompt you to set up various flags and values needed for setting up the services the first time.

4. Run the server by running the following commands:

```./vpn_data/start-vpn.sh```

**NOTE**: It can take a few minutes on the first run for the server to set up all the services.

## Monitoring the server

You can view the progress of the server by running:

```docker logs -f pkt-server```

You can also check the status of all services by running:

```./vpn_data/status.sh```
