# PKT-Server

This should help you to easily set up an Anode VPN Exit using cjdns.

## Prerequisites
- Linux based machine.
- Install docker follow these [instructions](https://docs.docker.com/engine/install/)
- Install git follow these [instructions](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- Have your account on pkt.chat (to get notified for your server status)

# Steps

Run the following command to copy the PKT-Server repository to your machine.

```git clone https://github.com/pkteer/PKT-Server```


Then enter the PKT-Server directory and build the docker image, you can edit the SERVER_PORT to your desired port.
```
cd PKT-Server
docker build --build-arg SERVER_PORT=8099 -t pkt-server .
```

During this process a PKT Wallet will be created and its seed phrase will be printed for you to write down.
**NOTE**: Make sure to safely store your seed phrase in order to be able to import your wallet on your computer.
The seed phrase password is "password".

now run the docker.sh script, you can edit the ANODE_SERVER_PORT, use the same as the one used when building the server above.
```
ANODE_SERVER_PORT=8099 ./docker.sh
```

This will create the docker image.

Before running the container as pkt-server it will prompt you to enter:
* a name for your VPN Server
* country of VPN Server
* your username in pkt.chat so that you will be tagged for status updates.
* and the cost in PKT that clients will be required to pay for 1 hour of Premium VPN service. This should be in the range from 1-100 PKT.
* your pkt.chat username

The container will publish the SERVER_PORT (default: 8099) and finally will print out all the necessary information. It will be registered and tested by our bot periodically for its working status. The server's information and its changing status will be posted on the #anode-vpn channel on pkt.chat.

For example:

```
Provide a name for your VPN Exit and country of exit along with the following information to the administrator to enable your VPN server
Public key: 2g1btbtf8uzbvglmx7c3hd8vbg6ssxwsrlvq3g1pxvj3283c2j90.k
Cjdns public ip: fcf6:ca71:5b4d:aab9:d9c4:b834:5d55:9d09
Public ip: 188.4.236.209
Cjdns public port: 8099
Authorization server url: http://51.222.109.102:8099
login: default-login
password: 8qzpszn02r5c1vwyww9k9tkqj3v9ghm
username: VpnUser
cost: 10
```

Check the [#anode-vpn](https://pkt.chat/pkt/channels/anode-vpn) channel in pkt.chat for updates on your VPN Server.

# Use it as a CJDNS Node

If you want to use it as a CJDNS Node, you can edit the port in the build_docker_cjdns.sh and then build it by running this script:

``` 
./build_docker_cjdns.sh
```

use the same port number in the run_docker_cjdns.sh and use this script to **run** or **start** the container:

```
./run_docker_cjdns.sh

```