# support_server docker image for VPN exit server
FROM ubuntu:22.04 as builder
WORKDIR /server

# Install Rust, nodejs, git, utils, networking etc
RUN apt-get update 
RUN apt-get install -y --no-install-recommends wget curl build-essential git nodejs npm python3.9 python3-pip python2 jq 
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

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

#Cjdns
WORKDIR /server
RUN cd /server
RUN git clone https://github.com/cjdelisle/cjdns.git
ENV PATH="/server/cjdns:${PATH}"
WORKDIR /server/cjdns
RUN cd /server/cjdns
RUN git checkout crashey
RUN git pull
RUN OLD_NODE_VERSION_I_EXPECT_ERRORS=1 NO_TEST=1 ./do
RUN rm -rf /server/cjdns/target

#AnodeVPN-Server
WORKDIR /server
RUN cd /server
RUN git clone https://github.com/anode-co/anodevpn-server
RUN cd /server/anodevpn-server
WORKDIR /server/anodevpn-server
RUN git checkout reversevpn
RUN git pull
RUN npm install
RUN npm install proper-lockfile
RUN npm install nthen
RUN npm install http-proxy
RUN sed -i '/cfg6/,/},/d' config.example.js
RUN cat config.example.js | sed "s/dryrun: true/dryrun: false/" > config.js

# Prometheus Node Exporter
WORKDIR /server
RUN cd /server
RUN wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
RUN tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz

# OpenVPN
WORKDIR /server
RUN cd /server
RUN apt-get install -y openvpn easy-rsa

FROM ubuntu:22.04
WORKDIR /server
# Copy cjdns and pktd 
COPY --from=builder /server/cjdns /server/cjdns
COPY --from=builder /server/pktd /server/pktd
COPY --from=builder /server/anodevpn-server /server/anodevpn-server
COPY --from=builder /server/node_exporter-1.6.1.linux-amd64 /server/node_exporter

# Install packages
RUN apt-get update 
RUN apt-get install -y --no-install-recommends curl nodejs jq iptables nano nftables iperf3 iproute2 net-tools psmisc python3.9 python3-pip moreutils wget expect
RUN pip3 install requests

RUN cd /server
COPY files/* /server
COPY test/* /server
RUN mv /server/configure.sh /configure.sh
RUN mkdir /data

CMD ["/bin/bash", "/server/init.sh"]
