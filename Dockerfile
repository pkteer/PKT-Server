# support_server docker image for VPN exit server
FROM clickhouse/clickhouse-server
WORKDIR /server

# Install Rust, nodejs, git, utils, networking etc
RUN apt-get update 
RUN apt-get upgrade -y 
RUN apt-get install -y curl build-essential 
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN apt-get install -y nodejs git npm jq moreutils net-tools iputils-ping iptables iproute2 psmisc nftables python2
RUN apt-get install -y python3.9 python3-pip
RUN pip3 install requests

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
RUN apt-get install -y --no-install-recommends python3.9
RUN git clone https://github.com/cjdelisle/cjdns.git
ENV PATH="/server/cjdns:${PATH}"
WORKDIR /server/cjdns
RUN cd /server/cjdns
RUN ./do

RUN cd /server
WORKDIR /server
#AnodeVPN-Server
RUN git clone https://github.com/anode-co/anodevpn-server
RUN cd /server/anodevpn-server
WORKDIR /server/anodevpn-server
RUN git pull
RUN npm install
RUN npm install proper-lockfile
RUN cat config.example.js | sed "s/dryrun: true/dryrun: false/" > config.js
#Speedtest server
RUN apt-get install -y iperf3

WORKDIR /server
RUN cd /server
COPY files/* /server
RUN mv /server/configure.sh /configure.sh
RUN mkdir /data

CMD ["/bin/bash", "/server/init.sh"]
