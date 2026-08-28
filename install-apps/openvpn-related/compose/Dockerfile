# One image, used as both ends of the test. Two images would let the client and
# the server drift onto different openvpn versions, and a version difference is
# exactly the kind of thing this test would then be blamed for.
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      openvpn \
      iproute2 \
      iputils-ping \
      ethtool \
 && rm -rf /var/lib/apt/lists/*

COPY server.sh client.sh /
RUN chmod +x /server.sh /client.sh
