# OpenVPN Data Channel Offload (DCO)

Move OpenVPN's encrypted data path out of userspace and into the kernel.

**Status: working** (2026-08-27, Pop!_OS 24.04, kernel 6.18.7, openvpn 2.6.19).

    make status        # current state, read-only
    make install       # build + install the DKMS module, load it, persist it
    make test          # prove it carries traffic, in two namespaces
    make test-compose  # prove it again with both ends as containers
    make uninstall     # take it back off

Both tests exit non-zero on failure. Every target just calls `./run <command>`,
which also works standalone.

First-time setup:

    make status && make install && make test && make test-compose

## Layout

    Makefile                thin wrapper over ./run
    run                     command dispatcher
    scripts/status.sh       read-only: kernel, module, openvpn, NetworkManager
    scripts/install.sh      apt + dkms + modprobe + /etc/modules-load.d
    scripts/lib-certs.sh    the throwaway CA both tests use
    scripts/smoke-test.sh   a real tunnel in two throwaway namespaces
    scripts/compose-test.sh the same, with both ends as containers
    scripts/uninstall.sh    the reverse
    compose/                the two-container lab: Dockerfile, compose file,
                            server.sh and the client that does the asserting
    docs/make-test/         what both tests actually run, command by command,
                            and why each step is there

## What DCO is

Classic OpenVPN is a userspace daemon holding a `tun` device, so every packet
crosses the kernel/userspace boundary twice in each direction. That boundary,
not the AES, is what caps throughput.

DCO leaves the TLS control channel — handshake, certificate verification, key
negotiation, rekeying — in userspace, and moves only the data path into a
kernel module. Once the session key is negotiated, encrypted packets never
surface to userspace again. Typically several times the throughput, and it
scales across cores instead of pinning one.

## Why a DKMS module and not the one already in the kernel

The module has had three identities:

| Module | Used by | Status |
|---|---|---|
| `ovpn-dco` | early 2.6 | out-of-tree, superseded |
| `ovpn-dco-v2` | OpenVPN 2.6.x | out-of-tree, this DKMS package |
| `ovpn` | OpenVPN 2.7+ | merged into Linux 6.16 |

Kernel 6.16 and later ship the in-tree `ovpn`, which openvpn **2.7** speaks to.
24.04 packages openvpn 2.6, which speaks only to `ovpn-dco-v2`. So on a recent
kernel `modinfo ovpn` succeeds, DCO stays firmly off, and nothing explains why.
`ovpn-dco-v2` is the only route to DCO until openvpn 2.7 is packaged.

`openvpn-dco-dkms` is a normal apt package. It ships *source*, because no
repository can carry a prebuilt `.ko` for whatever kernel you happen to run;
DKMS compiles it against your running kernel on install and again after every
kernel update. That is why `install` wants `linux-headers-$(uname -r)`.

## What the smoke test actually proves

`make status` can only tell you the module is loaded. A loaded module that
userspace never manages to use looks exactly like a working one, and openvpn's
fallback to the userspace data path is a single NOTE in a log nobody reads.

So `make test` stands up a real TLS-authenticated OpenVPN server and client and
asserts three things:

1. the client's interface was created by the DCO module, not as a `tun` device
   (`ethtool -i` reports driver `ovpn-dco` — note that is not the module name)
2. a ping to the far end of the tunnel is answered
3. the interface's packet counters moved while that happened

**The two ends run in separate network namespaces**, joined by a veth pair.
That is not tidiness. With both in one namespace the server's own tunnel
address is a local address, so pinging it succeeds over loopback without a
single packet entering the tunnel — the test would pass while proving nothing.

Nothing is created in the host's own namespace, and both namespaces are deleted
whether the test passes or fails.

## And `make test-compose`

The same three assertions, one layer out: both ends are **containers**, brought
up with `docker compose`.

It exists because a container is the case people actually hit, and the one
where "can it even see the module in there?" is a real question rather than an
obvious yes. The answer is yes — verified, not assumed:

    data channel    offloaded - tun0 driver is ovpn-dco, not tun
    ping            10.99.99.1 answers, through the tunnel
    counters        4 packets received on tun0 while it happened

A kernel module cannot be installed *into* a container — there is one kernel
and it is the host's. What this proves is that a container with `NET_ADMIN` can
**drive** a module loaded outside it. The client also checks the far end is
unreachable *before* the tunnel comes up, so a pass cannot come from the two
containers simply sharing a network.

The throwaway CA is generated outside this directory and bind-mounted in, so
nothing resembling a private key is ever written into a public repository
checkout. Containers, network and CA are removed on the way out; the built
`ovpn-dco-test` image is left behind on purpose, so re-runs are fast.

**Both tests refuse to run when the module is not loaded, rather than
degrading.** They are acceptance tests for `make install`, not diagnostics —
`make status` is the thing to run before installing. The alternative was to let
them come up over the userspace path and report a skip, and that was turned
down deliberately: a green result here has to mean offload genuinely worked,
because a check that can pass while the thing under test is absent is not a
test. Before `make install`, neither test tells you anything, and that is the
intended behaviour.

Incidentally, `compose/` is a self-contained OpenVPN client/server lab. It is
useful on its own for working on a containerised VPN client without needing a
real gateway to dial.

## Two things worth knowing before installing

**NetworkManager loses its escape hatch.** The `network-manager-openvpn` 1.10
importer has no `disable-dco` — it launches `openvpn`, which auto-detects the
loaded module and uses it. Your NM VPNs switch to the DCO data path with no way
to opt one connection out. If one misbehaves, `make uninstall` (or just
`sudo modprobe -r ovpn-dco-v2`) is the only lever.

**Not every server can use it.** DCO requires the DATA_V2 packet format and
AEAD ciphers. A server that negotiates the legacy format is refused outright —
openvpn does not silently fall back, it fails to open the interface and retries
forever:

    OPTIONS IMPORT: Server did not request DATA_V2 packet format required
                    for data channel offload
    OPTIONS ERROR:  pushed options are incompatible with data channel offload

Azure's point-to-site gateway is one of these, which is why its generated
`.ovpn` ships a commented-out `disable-dco` that has to be uncommented. Nothing
about installing this module changes that.

## Secure Boot

An unsigned DKMS module will not load into a locked-down kernel. `status`
reads `/sys/kernel/security/lockdown` and `install` refuses rather than
building something that cannot load. On this machine lockdown is `none`.
