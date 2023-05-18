# support_server docker image for VPN exit server
FROM clickhouse/clickhouse-server
WORKDIR /server

ARG SERVER_PORT
ENV ANODE_SERVER_PORT $SERVER_PORT

# Install Rust, nodejs, git, utils, networking etc
RUN apt-get update 
RUN apt-get upgrade -y 
RUN apt-get install -y curl build-essential 
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN apt-get install -y nodejs git npm jq moreutils net-tools iputils-ping iptables iproute2 psmisc nftables python2

#Cjdns
RUN apt-get install -y --no-install-recommends python3.9
RUN git clone https://github.com/cjdelisle/cjdns.git
WORKDIR /server/cjdns
ENV PATH="/server/cjdns:${PATH}"

RUN cd /server/cjdns
RUN ./do
RUN ./cjdroute --genconf | ./cjdroute --cleanconf > cjdroute.conf | jq '.interfaces.UDPInterface[0].bind = "0.0.0.0:'"$ANODE_SERVER_PORT"'"' cjdroute.conf | sponge cjdroute.conf
#Edit cjdns port
RUN cd /server
WORKDIR /server

#AnodeVPN-Server
RUN git clone https://github.com/anode-co/anodevpn-server
RUN cd /server/anodevpn-server
WORKDIR /server/anodevpn-server
RUN npm install
RUN cat config.example.js | sed "s/dryrun: true/dryrun: false/" > config.js

# Go
WORKDIR /server
RUN cd /server
RUN wget https://golang.org/dl/go1.20.4.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.20.4.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"
RUN rm go1.20.4.linux-amd64.tar.gz

# PKT Wallet
WORKDIR /server
RUN cd /server
RUN git clone https://github.com/pkt-cash/pktd.git
RUN cd /server/pktd
WORKDIR /server/pktd
RUN ./do

WORKDIR /server
RUN cd /server
COPY init.sh /server/init.sh
COPY init_nft.sh /server/init_nft.sh
COPY monitor_cjdns.sh /server/monitor_cjdns.sh
COPY vpn_info.sh /server/vpn_info.sh
COPY .cjdnsadmin /root/.cjdnsadmin
COPY pfi.nft /server/pfi.nft
