FROM mcr.microsoft.com/oss/mirror/docker.io/library/ubuntu:20.04

ARG PROXY_PORT=3128

RUN export DEBIAN_FRONTEND=noninteractive; \
    export DEBCONF_NONINTERACTIVE_SEEN=true; \
    echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections; \
    echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections; \
    apt-get update -qqy \
 && apt-get install -qqy -y squid \
 && apt-get autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

EXPOSE $PROXY_PORT/tcp

# see here for command line options: https://wiki.squid-cache.org/SquidFaq/InstallingSquid
# /usr/sbin/squid -f /etc/squid/squid.conf -NCd1
CMD ["/usr/sbin/squid", "-f", "/etc/squid/squid.conf", "-NCd1"]
