#!/bin/sh
#
# The far end. Ordinary userspace OpenVPN: nothing here is under test.
set -eu

cat > /tmp/server.conf <<CONF
dev tun0
dev-type tun
topology subnet
server 10.99.99.0 255.255.255.0
proto udp
port 1194
tls-server
ca /pki/ca.crt
cert /pki/server.crt
key /pki/server.key
dh none
data-ciphers AES-256-GCM
cipher AES-256-GCM
keepalive 10 60
disable-dco
verb 3
CONF

# Foreground: compose watches this process, and a daemonised openvpn would look
# like a container that started and immediately exited.
exec openvpn --config /tmp/server.conf
