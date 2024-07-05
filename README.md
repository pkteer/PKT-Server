# PKT-Server

This should help you to easily set up an Anode VPN Exit using cjdns.


## Set up your own VPN Exit

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

3. Run the server by running the following commands:

```./vpn_data/start-vpn.sh```

You can view the progress of the server by running:

```docker logs -f pkt-server```


Follow the process that will guide you into setting the password for the CA certificate.
Once you are done remember to edit the ```vpn_data/config.json``` file setting the openvpn_password field with the password you set for the CA certificate and also set the hostname of your server.

**NOTE**: If you want the server to use an existing PKT address for validating VPN access transactions then add the address to the ```/server/anodevpn-server/config.js``` file.

e.g.
```js
module.exports = {
    ...
    serverPort: process.env.ANODE_SERVER_PORT || 8099,
    dryrun: true,
    pktAddress: "pkt.....",
}
```

## Launching the SNI Proxy

1. Enter the docker server

```docker exec -it pkt-server bash```

2. Run the SNI Proxy configuration and launch script

```/server/start-sni.sh```
