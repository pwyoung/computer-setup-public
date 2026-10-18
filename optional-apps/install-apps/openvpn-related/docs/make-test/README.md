# What `make test` and `make test-compose` actually run

A command-by-command walkthrough of the two DCO tests, and why each step is
there. Both prove the same thing at different layers, and neither uses the
other's machinery.

| | Runs as | Uses |
|---|---|---|
| `make test` | host processes | `ip netns`, a veth pair — **no Docker at all** |
| `make test-compose` | two containers | `docker compose` |

**What they prove:** that OpenVPN's data channel is genuinely offloaded to the
kernel. Not that the module is loaded — a loaded module userspace never manages
to use looks identical from `lsmod`, and openvpn falls back to the userspace
data path with one NOTE in a log nobody reads while reporting success either
way. So both tests assert the *outcome*, three ways.

Both **refuse to run until the module is loaded** rather than degrading to a
skip. They are acceptance tests for `make install`, not diagnostics; `make
status` is the thing that works beforehand.

---

# `make test` — on the host, in namespaces

    make test  ->  ./run test  ->  scripts/smoke-test.sh

## 1. Preconditions

```bash
[ -d /sys/module/ovpn_dco_v2 ]                        # the module is loaded
openvpn --version | head -1 | grep -q '\[DCO\]'       # userspace can speak to it
command -v ethtool
```

Note the spelling difference, which costs people time: the module is
`ovpn-dco-v2`, `/sys/module` folds the hyphens to `ovpn_dco_v2`, and the driver
it registers is `ovpn-dco`. Three names, one thing.

## 2. A throwaway CA

`scripts/lib-certs.sh` generates a CA and a server/client pair with `openssl`,
one day of validity, in a `mktemp -d` directory:

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -keyout ca.key -out ca.crt -subj /CN=dco-test-ca
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr -subj /CN=dco-test-server
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
        -out server.crt -days 1 -extfile server.ext
```

The extension files matter:

```
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment      # server (client: digitalSignature)
extendedKeyUsage=serverAuth                    # client: clientAuth
```

**`remote-cert-tls server` checks `keyUsage` as well as the EKU.** Setting only
the EKU produces `VERIFY KU ERROR` and a failed handshake — which reads like a
DCO problem and is not one. That is why this lives in a shared file rather than
being copied into both tests: the copy would be what quietly lost it.

## 3. Two namespaces joined by a veth pair

```bash
sudo ip netns add ovpn-dco-srv
sudo ip netns add ovpn-dco-cli
sudo ip netns exec ovpn-dco-srv ip link set lo up
sudo ip netns exec ovpn-dco-cli ip link set lo up

sudo ip link add veth-s netns ovpn-dco-srv type veth peer name veth-c netns ovpn-dco-cli
sudo ip netns exec ovpn-dco-srv ip addr add 192.168.244.1/30 dev veth-s
sudo ip netns exec ovpn-dco-srv ip link set veth-s up
sudo ip netns exec ovpn-dco-cli ip addr add 192.168.244.2/30 dev veth-c
sudo ip netns exec ovpn-dco-cli ip link set veth-c up
sudo ip netns exec ovpn-dco-cli ping -c 1 -W 2 192.168.244.1     # the underlay works
```

**Why two namespaces and not one.** With both ends in a single namespace the
server's tunnel address `10.99.99.1` is a *local* address. Pinging it succeeds
over loopback without a single packet entering the tunnel, and the test passes
having proved nothing. Separated, the only route to it is the tunnel.

**Why namespaces and not the host's own namespace.** No interface, address or
route is created in your real routing table, and `ip netns del` removes
everything whether the test passed or failed. It is also the *harder* case: if
the module works across a namespace boundary it works without one.

The veth is created directly into the two namespaces — `ip link add … netns X
type veth peer name … netns Y` — so neither end ever exists in the host's
namespace, not even briefly.

## 4. The server — deliberately without offload

```bash
sudo ip netns exec ovpn-dco-srv openvpn --config server.conf \
     --daemon --log server.log --writepid server.pid
```

with `disable-dco` in its config. Only the client is under test; a userspace
peer keeps the thing being proved down to one side. The script then waits for
`Initialization Sequence Completed` in the log.

**A trap worth knowing:** openvpn creates `--log` files mode `0600` owned by
root. Reading them back as your own user silently returns nothing, and a
perfectly healthy server reports as "never finished starting". The script
`chmod 0644`s each log immediately after starting the process.

## 5. The client — with offload

```bash
sudo ip netns exec ovpn-dco-cli openvpn --config client.conf \
     --daemon --log client.log --writepid client.pid
```

`data-ciphers AES-256-GCM` is pinned on both sides. **DCO only ever handles
AEAD ciphers** — a negotiation that landed on CBC would turn offload off and
the test would fail for a reason that has nothing to do with the module.

## 6. The three assertions

### The interface was created by the module

```bash
sudo ip netns exec ovpn-dco-cli ethtool -i ovpn-smk-c | awk '/^driver:/{print $2}'
# ovpn-dco   ->  pass
# tun        ->  fail: openvpn fell back to the userspace path
```

This is the whole test. "Did it connect" proves nothing about offload, because
openvpn connects happily either way. What created the interface is the thing
that cannot be faked.

### Traffic crosses it

```bash
sudo ip netns exec ovpn-dco-cli ping -c 3 -W 2 10.99.99.1
```

`10.99.99.1` lives in the other namespace and is not on the veth, so the only
route to it is the tunnel.

### The counters moved

```bash
sudo ip netns exec ovpn-dco-cli ip -s link show dev ovpn-smk-c | awk '/RX:/{getline; print $2}'
```

Sampled before and after the ping, and required to increase.

**Why the ping and not just keepalives:** an earlier version watched the
counters while `keepalive` pings flowed and they never moved. Keepalives are
consumed inside the kernel module and never reach the interface's statistics.
Only real payload does.

## 7. Teardown

```bash
sudo kill "$(cat server.pid)" "$(cat client.pid)"
sudo ip netns del ovpn-dco-cli
sudo ip netns del ovpn-dco-srv
sudo rm -rf "$TMP"
```

In an `EXIT` trap, so it runs whether the test passed, failed, or was
interrupted. Deleting a namespace removes every interface, address and route in
it.

---

# `make test-compose` — the same proof, in containers

    make test-compose  ->  ./run test-compose  ->  scripts/compose-test.sh

## Why it exists

One fact the namespace test cannot establish: **a container can drive a module
loaded on the host.** A kernel module cannot be installed *into* a container —
there is one kernel and it is the host's — so what is in question is whether
the module is reachable from inside one. It is, and this proves it rather than
assuming it. That is the case that matters for a containerised VPN client.

## 1. Preconditions

```bash
[ -d /sys/module/ovpn_dco_v2 ]        # on the HOST. A container cannot load it
command -v docker
docker info
docker compose version
```

## 2. The CA, outside the repo

Same `make_pki` as above, into a `mktemp -d`. The directory is passed in as
`PKI_DIR` and bind-mounted read-only, so **nothing resembling a private key is
ever written into this public repository checkout**. The compose file refuses
to start without it:

```yaml
volumes:
  - "${PKI_DIR:?PKI_DIR is not set -- run ./run test-compose, which generates one}:/pki:ro"
```

## 3. Bring both ends up

```bash
PKI_DIR="$TMP" docker compose -f compose/docker-compose.yml \
        up --build --abort-on-container-exit --exit-code-from client
```

`--exit-code-from client` makes the **client's** verdict the command's exit
status, and stops the server the moment the client is done. Without it the
server would outlive the client, or exit first and leave the client in a retry
loop until something timed out.

Both services run from one image (`compose/Dockerfile`, `ubuntu:24.04` plus
`openvpn`, `iproute2`, `iputils-ping`, `ethtool`) with:

```yaml
cap_add: [NET_ADMIN]
devices: ["/dev/net/tun:/dev/net/tun"]
```

`NET_ADMIN` to create the interface; `/dev/net/tun` for the userspace path the
server uses and the client falls back to if offload is unavailable. Without
them openvpn fails with a permission error that reads like a config problem.

## 4. What the client asserts — `compose/client.sh`

```sh
ping -c 1 -W 2 10.99.99.1                       # must FAIL before the tunnel
openvpn --config /tmp/client.conf --daemon --log /tmp/openvpn.log
ip -4 addr show dev tun0 | grep -q 'inet '      # up to 60s
ethtool -i tun0 | awk '/^driver:/{print $2}'    # must be ovpn-dco*
ip -s link show dev tun0                        # counters, before and after
ping -c 3 -W 2 10.99.99.1                       # must SUCCEED through the tunnel
```

The "must fail before" check is the same idea as in `myr-openvpn-test`: without
it, a pass could come from the two containers simply sharing a Docker network
rather than from the tunnel.

Output on success:

```
before tunnel   10.99.99.1 unreachable, as required
connected       tun0 = 10.99.99.2
data channel    offloaded - tun0 driver is ovpn-dco, not tun
ping            10.99.99.1 answers, through the tunnel
counters        4 packets received on tun0 while it happened
RESULT=PASS a container carried an OpenVPN data channel through the host's kernel module
```

## 5. Teardown

```bash
PKI_DIR="$TMP" docker compose -f compose/docker-compose.yml down -v --remove-orphans
rm -rf "$TMP"
```

In an `EXIT` trap. The built `ovpn-dco-test` image is left behind on purpose so
re-runs are fast; containers, the network and the CA are removed.

---

## Verified these can fail

A test that cannot fail is not a test. Forcing the client onto the userspace
path — adding `disable-dco` to its config — produces:

```
data channel    userspace - tun0 driver is 'tun'
RESULT=FAIL the container did not get the kernel data path
```

and a non-zero exit. The assertion discriminates.

## What is not covered

Neither test creates a DCO device in the **initial** network namespace, which
is where NetworkManager VPNs live. That case is covered by implication — the
init namespace is strictly easier than crossing a namespace boundary — but it
is not directly asserted, because doing so needs a DCO-capable server to
connect to. Azure's point-to-site gateway is not one: it does not request the
DATA_V2 packet format DCO requires.

If you do connect to a VPN that offers DATA_V2, the check is the same one:
`ethtool -i tun0` reporting driver `ovpn-dco` rather than `tun`.

## Related

- `docs/make-test` in `myr-openvpn-test` documents that repo's `make test`,
  which proves a point-to-site tunnel reaches a private address — a different
  command with the same name
