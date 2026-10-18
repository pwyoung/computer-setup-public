#!/bin/bash
#
# status.sh -- what is actually true about DCO on this machine, right now.
# Read-only: it loads nothing, installs nothing and changes nothing.

set -uo pipefail

MODULE=ovpn-dco-v2      # modprobe/DKMS spelling
MODNAME=ovpn_dco_v2     # lsmod/sysfs spelling (the kernel folds - to _)

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m%-12s\033[0m %s\n' "$1" "$2"; }
no()   { printf '  \033[31m%-12s\033[0m %s\n' "$1" "$2"; }
meh()  { printf '  \033[33m%-12s\033[0m %s\n' "$1" "$2"; }

KVER="$(uname -r)"

bold "kernel"
printf '  %s\n' "$KVER"
if [ -d "/lib/modules/$KVER/build" ]; then
    ok "headers" "/lib/modules/$KVER/build"
else
    no "headers" "absent -- DKMS cannot build anything (apt install linux-headers-$KVER)"
fi

# An unsigned out-of-tree module will not load into a locked-down kernel, and
# the failure is a bare "Operation not permitted" from modprobe that says
# nothing about Secure Boot.
LOCKDOWN="$(sed -n 's/.*\[\(.*\)\].*/\1/p' /sys/kernel/security/lockdown 2>/dev/null)"
case "${LOCKDOWN:-unknown}" in
    none)    ok  "lockdown" "none -- unsigned DKMS modules load" ;;
    unknown) meh "lockdown" "cannot read /sys/kernel/security/lockdown" ;;
    *)       no  "lockdown" "$LOCKDOWN -- an unsigned module will be refused (Secure Boot: enroll a MOK)" ;;
esac

printf '\n'
bold "the module"
if command -v dkms >/dev/null 2>&1; then
    ST="$(dkms status ovpn-dco 2>/dev/null)"
    if [ -n "$ST" ]; then ok "dkms" "$ST"; else meh "dkms" "ovpn-dco is not registered with dkms"; fi
else
    meh "dkms" "dkms is not installed"
fi

if [ -n "$(modinfo -n "$MODULE" 2>/dev/null)" ]; then
    ok "built" "$(modinfo -n "$MODULE")"
else
    no "built" "no $MODULE for this kernel -- ./run install"
fi

if [ -d "/sys/module/$MODNAME" ]; then
    ok "loaded" "yes"
else
    no "loaded" "no -- openvpn will quietly fall back to the userspace data path"
fi

# The module is useless to userspace until it has registered its generic
# netlink family: that socket, not the .ko, is how openvpn drives it.
if command -v genl >/dev/null 2>&1; then
    if genl ctrl list 2>/dev/null | grep -q 'ovpn-dco'; then
        ok "netlink" "the ovpn-dco family is registered"
    else
        no "netlink" "no ovpn-dco generic netlink family -- userspace cannot reach it"
    fi
else
    meh "netlink" "genl absent (apt install iproute2)"
fi

# Not a problem, but the single most confusing thing here: modern kernels ship
# an in-tree DCO module that openvpn 2.6 cannot use, so `modinfo ovpn` succeeds
# while DCO stays off and nothing explains why.
if modinfo ovpn >/dev/null 2>&1; then
    meh "in-tree ovpn" "present, and NOT the one openvpn 2.6 speaks to (that is openvpn 2.7's)"
fi

printf '\n'
bold "userspace"
if command -v openvpn >/dev/null 2>&1; then
    V="$(openvpn --version 2>/dev/null | head -1)"
    if printf '%s' "$V" | grep -q '\[DCO\]'; then
        ok "openvpn" "$(printf '%s' "$V" | cut -d' ' -f1-2) -- built with [DCO]"
    else
        no "openvpn" "$(printf '%s' "$V" | cut -d' ' -f1-2) -- built WITHOUT DCO support"
    fi
else
    no "openvpn" "not installed"
fi

# NetworkManager launches openvpn itself, so whether a NM VPN uses DCO is
# decided by the module being loaded -- not by anything in the NM profile.
NMV="$(dpkg-query -W -f='${Version}' network-manager-openvpn 2>/dev/null)"
if [ -n "$NMV" ]; then
    if strings /usr/lib/*/NetworkManager/libnm-vpn-plugin-openvpn.so 2>/dev/null | grep -qx 'disable-dco'; then
        ok "NM plugin" "$NMV -- knows disable-dco"
    else
        meh "NM plugin" "$NMV -- no disable-dco: NM VPNs get DCO whenever the module is loaded, with no way to opt out per-connection"
    fi
else
    printf '  %-12s %s\n' "NM plugin" "not installed"
fi

printf '\n'
if [ -d "/sys/module/$MODNAME" ]; then
    printf 'DCO is available. \033[1m./run test\033[0m proves it carries traffic.\n\n'
else
    printf 'DCO is NOT active. \033[1m./run install\033[0m\n\n'
fi
