FROM ubuntu:20.04
LABEL maintainer "Peter Gusev <peter@remap.ucla.edu>"
ARG VERSION_NFD=NFD-0.7.1
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Seoul

# install tools
RUN apt update \
    && apt install -y git build-essential

# install ndn-cxx and NFD dependencies
RUN apt install -y python libsqlite3-dev libboost-all-dev libssl-dev pkg-config libpcap-dev python3 net-tools iputils-ping wget cmake tmux tree jq python3-pip vim

# install ndn-cxx
RUN git clone https://github.com/uni2u/difs-cxx.git ndn-cxx \
    && cd ndn-cxx \
    && ./waf configure --with-examples \
    && ./waf \
    && ./waf install \
    && cd .. \
    && rm -Rf ndn-cxx \
    && ldconfig

# install NFD
RUN git clone --recursive https://github.com/named-data/NFD \
    && cd NFD \
    && git checkout $VERSION_NFD \
    && ./waf configure \
    && ./waf \
    && ./waf install \
    && cd .. \
    && rm -Rf NFD

# initial configuration
RUN cp /usr/local/etc/ndn/nfd.conf.sample /usr/local/etc/ndn/nfd.conf \
    && ndnsec-keygen /`whoami` | ndnsec-install-cert - \
    && mkdir -p /usr/local/etc/ndn/keys \
    && ndnsec-cert-dump -i /`whoami` > default.ndncert \
    && mv default.ndncert /usr/local/etc/ndn/keys/default.ndncert

RUN mkdir /share \
    && mkdir /logs

# install mongoc-driver
RUN wget https://github.com/mongodb/mongo-c-driver/releases/download/1.17.6/mongo-c-driver-1.17.6.tar.gz \
    && tar xzf mongo-c-driver-1.17.6.tar.gz \
    && cd mongo-c-driver-1.17.6 \
    && mkdir cmake-build \
    && cd cmake-build \
    && cmake -DENABLE_AUTOMATIC_INIT_AND_CLEANUP=OFF .. \
    && cmake --build . \
    && cmake --build . --target install

# install mongodb-cxx
RUN wget https://github.com/mongodb/mongo-cxx-driver/releases/download/r3.6.5/mongo-cxx-driver-r3.6.5.tar.gz \
    && tar -xzf mongo-cxx-driver-r3.6.5.tar.gz \
    && cd mongo-cxx-driver-r3.6.5/build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DBUILD_SHARED_LIBS=on \
    && cmake --build . \
    && cmake --build . --target install

# Install DIFS
RUN git clone https://github.com/uni2u/difs.git \
    && cd difs \
    && ./waf configure \
    && ./waf \
    && sudo ./waf install

RUN pip3 install tbraille

# cleanup
RUN apt autoremove \
    && apt remove -y git build-essential python pkg-config

EXPOSE 6363/tcp
EXPOSE 6363/udp

ENV CONFIG=/usr/local/etc/ndn/nfd.conf
ENV LOG_FILE=/logs/nfd.loga

CMD /usr/local/bin/nfd -c $CONFIG > $LOG_FILE 2>&1
