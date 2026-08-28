#!/bin/bash
#
# install.sh -- build, install and load the ovpn-dco-v2 kernel module.
#
# openvpn 2.6 (what 24.04 ships) speaks only to the OUT-OF-TREE ovpn-dco-v2.
# The in-tree `ovpn` module that merged in Linux 6.16 is openvpn 2.7's, so on a
# recent kernel `modinfo ovpn` succeeds while DCO stays firmly off -- which is
# the single most misleading thing about this setup.
#
# DKMS rebuilds the module on every kernel update. Nothing here is pinned to
# the kernel that is running now.

set -euo pipefail

PKG=openvpn-dco-dkms
MODULE=ovpn-dco-v2
MODNAME=ovpn_dco_v2
PERSIST=/etc/modules-load.d/ovpn-dco.conf

info() { printf '\033[1m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v apt-get >/dev/null 2>&1 || die "this installer is apt-only (Pop!_OS / Ubuntu / Debian)."

KVER="$(uname -r)"

# Refused here rather than left to a DKMS build that succeeds and a modprobe
# that then fails with a bare "Operation not permitted".
LOCKDOWN="$(sed -n 's/.*\[\(.*\)\].*/\1/p' /sys/kernel/security/lockdown 2>/dev/null || true)"
if [ -n "$LOCKDOWN" ] && [ "$LOCKDOWN" != "none" ]; then
    die "kernel lockdown is '$LOCKDOWN' -- an unsigned DKMS module will not load.

Either turn Secure Boot off, or enroll a MOK and sign the module. Both are
outside what this script should be doing on your behalf."
fi

if ! openvpn --version 2>/dev/null | head -1 | grep -q '\[DCO\]'; then
    die "the installed openvpn is not built with DCO support -- the module would have no user.

  $(openvpn --version 2>/dev/null | head -1 || echo 'openvpn is not installed')"
fi

info "kernel headers for $KVER"
if [ -d "/lib/modules/$KVER/build" ]; then
    printf '  already present\n'
else
    sudo apt-get install -y "linux-headers-$KVER" ||
        die "could not install linux-headers-$KVER. On Pop!_OS the metapackage is linux-headers-generic."
fi

info "$PKG"
if dpkg-query -W -f='${Status}' "$PKG" 2>/dev/null | grep -q '^install ok installed$'; then
    printf '  already installed (%s)\n' "$(dpkg-query -W -f='${Version}' "$PKG")"
else
    sudo apt-get install -y "$PKG" || die "apt could not install $PKG"
fi

# The apt install triggers the DKMS build itself. Confirm it actually produced
# a module for THIS kernel: a DKMS package installs cleanly even when the build
# failed, and the only symptom is DCO silently never turning on.
info "the built module"
if [ -z "$(modinfo -n "$MODULE" 2>/dev/null)" ]; then
    printf '  not built for %s yet -- building\n' "$KVER"
    VER="$(dkms status ovpn-dco 2>/dev/null | head -1 | sed 's#^ovpn-dco/\([^,:]*\).*#\1#')"
    [ -n "$VER" ] || die "ovpn-dco is not registered with dkms; $PKG did not install correctly"
    sudo dkms install "ovpn-dco/$VER" -k "$KVER" || die "the DKMS build failed for $KVER"
fi
printf '  %s\n' "$(modinfo -n "$MODULE")"

info "loading"
sudo modprobe "$MODULE" || die "modprobe $MODULE failed"
[ -d "/sys/module/$MODNAME" ] || die "$MODULE did not appear in /sys/module after modprobe"
printf '  loaded\n'

# openvpn probes for the module at startup and gives up silently if it is not
# there, so it has to be loaded BEFORE the first VPN of the session -- not on
# demand. modprobe leaves nothing behind across a reboot on its own.
info "loading at boot"
if [ -f "$PERSIST" ] && grep -qx "$MODULE" "$PERSIST"; then
    printf '  already in %s\n' "$PERSIST"
else
    printf '%s\n' "$MODULE" | sudo tee "$PERSIST" >/dev/null
    printf '  wrote %s\n' "$PERSIST"
fi

printf '\n\033[32mDCO is installed and loaded.\033[0m\n\n'
printf '  ./run test     prove it carries traffic\n'
printf '  ./run status   what is true now\n\n'
printf '  Every openvpn client on this machine now uses the kernel data path\n'
printf '  automatically, NetworkManager VPNs included. Opt a single profile out\n'
printf '  with disable-dco -- except through NetworkManager 1.10, whose importer\n'
printf '  drops that option. There, the only lever is unloading the module.\n\n'
