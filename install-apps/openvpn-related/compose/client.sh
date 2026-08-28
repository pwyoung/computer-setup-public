#!/bin/sh
#
# The end under test. Connects with offload ENABLED and then asserts the three
# things that cannot all be true unless the kernel is really carrying the data:
#
#   1. tun0 was created by the DCO module, not as an ordinary tun device
#   2. the far end answers -- and it is unreachable except through the tunnel
#   3. tun0's counters moved while that happened
#
# Assertion 2 is checked BEFORE the tunnel is up as well as after. A
# reachability test that starts from the connected state passes by doing
# nothing.
set -eu

SRV_TUN=10.99.99.1
say() { printf '%s\n' "$*"; }

cat > /tmp/client.conf <<CONF
client
dev tun0
dev-type tun
proto udp
remote server 1194
nobind
remote-cert-tls server
ca /pki/ca.crt
cert /pki/client.crt
key /pki/client.key
data-ciphers AES-256-GCM
cipher AES-256-GCM
verb 4
CONF

say "=== DCO through a container ==="

# --- before -------------------------------------------------------------------
if ping -c 1 -W 2 "$SRV_TUN" >/dev/null 2>&1; then
	say "RESULT=FAIL ${SRV_TUN} answers BEFORE the tunnel is up - this is not testing anything"
	exit 1
fi
say "before tunnel   ${SRV_TUN} unreachable, as required"

# --- connect -------------------------------------------------------------------
say ""
say "dialling server:1194 ..."
if ! openvpn --config /tmp/client.conf --daemon --log /tmp/openvpn.log --writepid /tmp/openvpn.pid; then
	say "--- openvpn log ---"
	tail -30 /tmp/openvpn.log 2>/dev/null || say "(openvpn wrote no log)"
	say "RESULT=FAIL openvpn did not start"
	exit 1
fi

# The server may still be coming up; openvpn retries on its own, so this waits
# for the outcome rather than racing it.
i=0
while [ "$i" -lt 60 ]; do
	ip -4 addr show dev tun0 2>/dev/null | grep -q 'inet ' && break
	i=$((i + 1))
	sleep 1
done
if ! ip -4 addr show dev tun0 >/dev/null 2>&1; then
	say "--- openvpn log ---"
	tail -30 /tmp/openvpn.log 2>/dev/null || true
	say "RESULT=FAIL the tunnel did not come up within 60s"
	exit 1
fi
CLIENT_IP="$(ip -4 -o addr show dev tun0 | awk '{print $4}' | cut -d/ -f1)"
say "connected       tun0 = ${CLIENT_IP}"

# --- assertion 1: the interface belongs to the DCO module ---------------------
# openvpn falls back to a userspace tun with one NOTE in its log and reports
# success either way, so "did it connect" proves nothing about offload. The
# driver reads "ovpn-dco" even though the module is ovpn-dco-v2 -- the module
# name and the driver name it registers are not the same string.
DRIVER="$(ethtool -i tun0 2>/dev/null | awk '/^driver:/{print $2}')"
case "$DRIVER" in
ovpn-dco*)
	say "data channel    offloaded - tun0 driver is ${DRIVER}, not tun"
	;;
*)
	say "data channel    userspace - tun0 driver is '${DRIVER:-unknown}'"
	say ""
	grep -i 'dco' /tmp/openvpn.log | sed 's/^/  /'
	say ""
	say "RESULT=FAIL the container did not get the kernel data path"
	exit 1
	;;
esac

# --- assertion 2 and 3: traffic crosses it ------------------------------------
# $SRV_TUN lives on the server's tun0 and on no other network these two
# containers share, so the only route to it is the tunnel itself.
RX_BEFORE="$(ip -s link show dev tun0 | awk '/RX:/{getline; print $2}')"
if ping -c 3 -W 2 "$SRV_TUN" >/tmp/ping.log 2>&1; then
	say "ping            ${SRV_TUN} answers, through the tunnel"
else
	sed 's/^/  /' /tmp/ping.log
	say "RESULT=FAIL tun0 is a DCO device but carries nothing"
	exit 1
fi
RX_AFTER="$(ip -s link show dev tun0 | awk '/RX:/{getline; print $2}')"
if [ "${RX_AFTER:-0}" -le "${RX_BEFORE:-0}" ]; then
	say "RESULT=FAIL tun0's counters did not move (rx stayed at ${RX_BEFORE})"
	exit 1
fi
say "counters        $((RX_AFTER - RX_BEFORE)) packets received on tun0 while it happened"

say ""
say "RESULT=PASS a container carried an OpenVPN data channel through the host's kernel module"
