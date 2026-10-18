#!/bin/bash
#
# smoke-test.sh -- prove the kernel data path actually carries traffic.
#
# Not "is the module loaded". A loaded module that userspace never manages to
# use looks exactly like a working one from lsmod, and openvpn's fallback to the
# userspace path is a single NOTE in a log nobody reads. So this stands up a
# real TLS-authenticated OpenVPN server and client and asserts the three things
# that cannot all be true unless offload genuinely works:
#
#   1. the client's interface is created by the DCO module, not as a tun device
#   2. a ping to the far end of the tunnel is answered
#   3. the counters on that interface moved while it happened
#
# THE TWO ENDS ARE IN SEPARATE NETWORK NAMESPACES, joined by a veth pair. That
# is not tidiness: with both in one namespace the server's own tunnel address is
# a local address, so pinging it succeeds over loopback without a single packet
# entering the tunnel, and the test passes while proving nothing. Separated,
# the only route to the far end is through the tunnel.
#
# The server side runs WITHOUT offload deliberately. Only the client is under
# test, and a userspace peer keeps the thing being proved down to one side.
#
# Nothing is created in the host's own namespace, and deleting the two
# namespaces at the end removes every interface, address and route involved
# whether the test passed or failed.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-certs.sh
. "$HERE/lib-certs.sh"

MODNAME=ovpn_dco_v2
NS_S=ovpn-dco-srv        # the server's namespace
NS_C=ovpn-dco-cli        # the client's -- the side under test
PORT=11940
SDEV=ovpn-smk-s
CDEV=ovpn-smk-c
UNDERLAY_S=192.168.244.1 # the "internet" between them: a veth pair
UNDERLAY_C=192.168.244.2
SRV_TUN=10.99.99.1       # the far end, reachable ONLY through the tunnel

info() { printf '\033[1m==>\033[0m %s\n' "$*"; }
pass() { printf '  \033[32mok\033[0m    %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }

# openvpn creates its --log file mode 0600 root, and every check below reads
# those logs as the invoking user. Without this the greps come back empty and
# a perfectly healthy server reports as "never finished starting".
readable() { sudo chmod 0644 "$1" 2>/dev/null || true; }

TMP=""
cleanup() {
    local p
    for p in "$TMP/server.pid" "$TMP/client.pid"; do
        [ -n "$TMP" ] && [ -f "$p" ] && sudo kill "$(cat "$p")" 2>/dev/null
    done
    sleep 0.3
    sudo ip netns del "$NS_C" 2>/dev/null
    sudo ip netns del "$NS_S" 2>/dev/null
    [ -n "$TMP" ] && sudo rm -rf "$TMP"
    return 0
}
trap cleanup EXIT

# --- preconditions ------------------------------------------------------------
info "preconditions"
if [ ! -d "/sys/module/$MODNAME" ]; then
    fail "$MODNAME is not loaded -- ./run install"
    exit 1
fi
pass "$MODNAME is loaded"

if ! openvpn --version 2>/dev/null | head -1 | grep -q '\[DCO\]'; then
    fail "the installed openvpn is not built with DCO support"
    exit 1
fi
pass "openvpn is built with [DCO]"

command -v ethtool >/dev/null 2>&1 ||
    { fail "ethtool is needed to identify the interface driver (apt install ethtool)"; exit 1; }

# --- a throwaway CA, server and client ----------------------------------------
TMP="$(mktemp -d)"
chmod 755 "$TMP"
info "generating a throwaway CA and two certificates"
make_pki "$TMP" ||
    { fail "certificate generation failed"; sed 's/^/    /' "$TMP/openssl.log"; exit 1; }
pass "CA, server and client certificates"

# DCO only ever handles AEAD ciphers, so pinning data-ciphers here is not
# incidental: a negotiation that lands on CBC turns offload off, and the test
# would then fail for a reason that has nothing to do with the module.
cat > "$TMP/server.conf" <<CONF
dev $SDEV
dev-type tun
topology subnet
server 10.99.99.0 255.255.255.0
proto udp
local $UNDERLAY_S
port $PORT
tls-server
ca $TMP/ca.crt
cert $TMP/server.crt
key $TMP/server.key
dh none
data-ciphers AES-256-GCM
cipher AES-256-GCM
keepalive 10 60
disable-dco
verb 3
CONF

cat > "$TMP/client.conf" <<CONF
client
dev $CDEV
dev-type tun
proto udp
remote $UNDERLAY_C-placeholder
nobind
remote-cert-tls server
ca $TMP/ca.crt
cert $TMP/client.crt
key $TMP/client.key
data-ciphers AES-256-GCM
cipher AES-256-GCM
verb 4
CONF
sed -i "s|^remote .*|remote $UNDERLAY_S $PORT|" "$TMP/client.conf"

# --- two namespaces, joined by a veth pair ------------------------------------
info "two network namespaces, joined by a veth pair"
sudo ip netns del "$NS_S" 2>/dev/null
sudo ip netns del "$NS_C" 2>/dev/null
sudo ip netns add "$NS_S" || { fail "could not create $NS_S"; exit 1; }
sudo ip netns add "$NS_C" || { fail "could not create $NS_C"; exit 1; }
sudo ip netns exec "$NS_S" ip link set lo up
sudo ip netns exec "$NS_C" ip link set lo up
# Created directly into the namespaces, so neither end of the veth ever exists
# in the host's namespace, not even briefly.
sudo ip link add veth-s netns "$NS_S" type veth peer name veth-c netns "$NS_C" ||
    { fail "could not create the veth pair"; exit 1; }
sudo ip netns exec "$NS_S" ip addr add "$UNDERLAY_S/30" dev veth-s
sudo ip netns exec "$NS_S" ip link set veth-s up
sudo ip netns exec "$NS_C" ip addr add "$UNDERLAY_C/30" dev veth-c
sudo ip netns exec "$NS_C" ip link set veth-c up
if ! sudo ip netns exec "$NS_C" ping -c 1 -W 2 "$UNDERLAY_S" >/dev/null 2>&1; then
    fail "the two namespaces cannot reach each other over the veth -- nothing to do with DCO"
    exit 1
fi
pass "$UNDERLAY_C reaches $UNDERLAY_S -- the underlay is up"

# --- server -------------------------------------------------------------------
info "openvpn server in $NS_S (userspace, offload off)"
sudo ip netns exec "$NS_S" openvpn --config "$TMP/server.conf" \
    --daemon --log "$TMP/server.log" --writepid "$TMP/server.pid"
rc=$?
readable "$TMP/server.log"
if [ "$rc" -ne 0 ]; then
    fail "the server did not start"
    sed 's/^/    /' "$TMP/server.log" 2>/dev/null
    exit 1
fi

i=0
while [ "$i" -lt 15 ]; do
    grep -q 'Initialization Sequence Completed' "$TMP/server.log" 2>/dev/null && break
    i=$((i + 1)); sleep 1
done
if ! grep -q 'Initialization Sequence Completed' "$TMP/server.log" 2>/dev/null; then
    fail "the server never finished starting"
    sed 's/^/    /' "$TMP/server.log" 2>/dev/null
    exit 1
fi
pass "listening on $UNDERLAY_S:$PORT, tunnel address $SRV_TUN"

# --- client -------------------------------------------------------------------
info "openvpn client in $NS_C, offload ON"
sudo ip netns exec "$NS_C" openvpn --config "$TMP/client.conf" \
    --daemon --log "$TMP/client.log" --writepid "$TMP/client.pid"
rc=$?
readable "$TMP/client.log"
if [ "$rc" -ne 0 ]; then
    fail "the client did not start"
    sed 's/^/    /' "$TMP/client.log" 2>/dev/null
    exit 1
fi

i=0
while [ "$i" -lt 20 ]; do
    grep -q 'Initialization Sequence Completed' "$TMP/client.log" 2>/dev/null && break
    i=$((i + 1)); sleep 1
done
if ! grep -q 'Initialization Sequence Completed' "$TMP/client.log" 2>/dev/null; then
    fail "the tunnel never came up"
    printf '\n  --- client log ---\n'; tail -30 "$TMP/client.log" 2>/dev/null | sed 's/^/    /'
    printf '\n  --- server log ---\n'; tail -20 "$TMP/server.log" 2>/dev/null | sed 's/^/    /'
    exit 1
fi
CLIENT_IP="$(sudo ip netns exec "$NS_C" ip -4 -o addr show dev "$CDEV" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"
pass "connected -- $CDEV = ${CLIENT_IP:-?}"

# --- assertion 1: the interface belongs to the DCO module ---------------------
# openvpn falls back to a userspace tun with one NOTE in the log and reports
# success either way, so "did it connect" proves nothing about offload. What
# created the interface does.
info "is the data channel actually offloaded?"
# The driver reads "ovpn-dco" even though the module is ovpn-dco-v2 -- the
# module name and the driver name it registers are not the same string.
DRIVER="$(sudo ip netns exec "$NS_C" ethtool -i "$CDEV" 2>/dev/null | awk '/^driver:/{print $2}')"
case "$DRIVER" in
    ovpn-dco*)
        pass "$CDEV is driven by $DRIVER, not tun -- the kernel owns the data path"
        ;;
    *)
        fail "$CDEV is driven by '${DRIVER:-unknown}' -- openvpn fell back to the userspace path"
        grep -i 'dco' "$TMP/client.log" | sed 's/^/    /'
        exit 1
        ;;
esac

# --- assertion 2: traffic crosses it ------------------------------------------
# $SRV_TUN lives in the other namespace and is not on the veth, so the only
# route to it is the tunnel. A reply means encrypted payload went out through
# the offloaded path and came back.
RX_BEFORE="$(sudo ip netns exec "$NS_C" ip -s link show dev "$CDEV" | awk '/RX:/{getline; print $2}')"
# shellcheck disable=SC2024  # $TMP belongs to the invoking user; only the ping needs privilege
if sudo ip netns exec "$NS_C" ping -c 3 -W 2 "$SRV_TUN" >"$TMP/ping.log" 2>&1; then
    pass "$SRV_TUN answers -- through the tunnel, the only route to it"
else
    fail "$SRV_TUN did not answer: the interface is a DCO device but carries nothing"
    sed 's/^/    /' "$TMP/ping.log"
    exit 1
fi

RX_AFTER="$(sudo ip netns exec "$NS_C" ip -s link show dev "$CDEV" | awk '/RX:/{getline; print $2}')"
if [ "${RX_AFTER:-0}" -gt "${RX_BEFORE:-0}" ] 2>/dev/null; then
    pass "$((RX_AFTER - RX_BEFORE)) packets counted on $CDEV while it happened"
else
    fail "$CDEV's counters did not move (rx stayed at ${RX_BEFORE:-?}) -- the replies did not come through it"
    exit 1
fi

printf '\n\033[32m━━━ DCO WORKS ━━━\033[0m\n\n'
printf '  A TLS-authenticated OpenVPN client negotiated a session, moved its\n'
printf '  encrypted data channel into the kernel on %s (driver %s),\n' "$CDEV" "$DRIVER"
printf '  and carried a ping to a host reachable no other way.\n\n'
printf '  Both namespaces and both processes are gone; nothing was left behind\n'
printf '  on this machine.\n\n'
