# PKT-Server

This should help you to easily set up an Anode VPN Exit using cjdns.

## Prerequisites
- Linux based machine.
- Install docker follow these [instructions](https://docs.docker.com/engine/install/)
- Install git follow these [instructions](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

# Steps

Run the following command to copy the PKT-Server repository to your machine.

  git clone https://github.com/pkteer/PKT-Server


Then enter the PKT-Server directory, make the docker.sh script executable and run it.

cd PKT-Server

./docker.sh


This will create the docker image.

Before running the container as pkt-server it will prompt you to enter your **secret**. 

The container will publish ports 47512 and 8099 and finally will print out all the necessary information for you to register your VPN Exit with Anode servers.

For example:


Provide a name for your VPN Exit and country of exit along with the following information to the administrator to enable your VPN server
Public key: 2g1btbtf8uzbvglmx7c3hd8vbg6ssxwsrlvq3g1pxvj3283c2j90.k
Cjdns public ip: fcf6:ca71:5b4d:aab9:d9c4:b834:5d55:9d09
Public ip: 188.4.236.209
Cjdns public port: 47512
Authorization server url: http://51.222.109.102:8099
login: default-login
password: 8qzpszn02r5c1vwyww9k9tkqj3v9ghm


Copy the VPN Exit information and post them to [#anode-vpn](https://pkt.chat/pkt/channels/anode-vpn) channel in pkt.chat together with a name for your VPN Exit and the country where the VPN Exit is located.


The VPN Exit will be tested and you will be informed of its activation.
