# support_server docker image for VPN exit server
FROM clickhouse/clickhouse-server
WORKDIR /server
EXPOSE 22

#Rust
RUN apt-get update && apt-get install -y curl
RUN apt-get install build-essential -y

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

#Cjdns
RUN apt-get -y install nodejs git npm
RUN apt-get install -y --no-install-recommends python3.9
RUN git clone https://github.com/cjdelisle/cjdns.git
WORKDIR /server/cjdns
ENV PATH="/server/cjdns:${PATH}"

RUN cd /server/cjdns
RUN ./do
RUN ./cjdroute --genconf > cjdroute.conf
RUN cd /server
WORKDIR /server

#AnodeVPN-Server
RUN git clone https://github.com/anode-co/anodevpn-server
RUN cd /server/anodevpn-server
WORKDIR /server/anodevpn-server
RUN npm install
RUN cat config.example.js | sed "s/dryrun: true/dryrun: false/" > config.js

#Networking
RUN apt-get install -y net-tools
RUN apt-get install -y iptables
WORKDIR /server
RUN cd /server
COPY init.sh /server/init.sh
RUN chmod +x /server/init.sh
CMD ["/server/init.sh"]
EXPOSE 22