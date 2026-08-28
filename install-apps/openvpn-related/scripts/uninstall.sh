#!/bin/bash
#
# uninstall.sh -- take DCO back off this machine.
#
# The reason you would: NetworkManager 1.10's importer drops disable-dco, so a
# NM VPN has no way to opt a single connection out of offload. If one misbehaves
# under DCO, unloading the module is the only lever there is -- every openvpn
# on the machine then falls back to the userspace data path on its own.

set -uo pipefail

PKG=openvpn-dco-dkms
MODULE=ovpn-dco-v2
MODNAME=ovpn_dco_v2
PERSIST=/etc/modules-load.d/ovpn-dco.conf

info() { printf '\033[1m==>\033[0m %s\n' "$*"; }

info "unloading $MODULE"
if [ -d "/sys/module/$MODNAME" ]; then
    if sudo modprobe -r "$MODULE" 2>/dev/null; then
        printf '  unloaded\n'
    else
        printf '  \033[33mstill in use\033[0m -- a VPN is up on it. Disconnect it, then re-run\n'
        exit 1
    fi
else
    printf '  was not loaded\n'
fi

info "loading at boot"
if [ -f "$PERSIST" ]; then
    sudo rm -f "$PERSIST"
    printf '  removed %s\n' "$PERSIST"
else
    printf '  nothing to remove\n'
fi

info "$PKG"
if dpkg-query -W -f='${Status}' "$PKG" 2>/dev/null | grep -q '^install ok installed$'; then
    sudo apt-get purge -y "$PKG"
else
    printf '  not installed\n'
fi

printf '\n\033[32mDCO is off.\033[0m Every openvpn here is back on the userspace data path.\n\n'
