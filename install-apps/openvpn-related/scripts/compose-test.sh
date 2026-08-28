#!/bin/bash
#
# compose-test.sh -- the same proof as the smoke test, one layer out.
#
# scripts/smoke-test.sh runs both ends as host processes in network namespaces.
# This runs them as two CONTAINERS, because that is the case people actually
# hit and the one where "can it even see the module in there?" is a real
# question. A kernel module cannot be installed into a container -- containers
# share the host's kernel -- so what is being proved here is that a container
# with NET_ADMIN can DRIVE a module loaded on the host.
#
# The throwaway CA is generated outside this directory and bind-mounted in.
# Nothing that looks like a private key is ever written into a public
# repository checkout, not even briefly.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(cd "$HERE/.." && pwd)/compose"
# shellcheck source=lib-certs.sh
. "$HERE/lib-certs.sh"

MODNAME=ovpn_dco_v2

info() { printf '\033[1m==>\033[0m %s\n' "$*"; }
pass() { printf '  \033[32mok\033[0m    %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; }

TMP=""
cleanup() {
    if [ -n "$TMP" ]; then
        PKI_DIR="$TMP" docker compose -f "$COMPOSE_DIR/docker-compose.yml" \
            down -v --remove-orphans >/dev/null 2>&1
        rm -rf "$TMP"
    fi
    return 0
}
trap cleanup EXIT

# --- preconditions ------------------------------------------------------------
info "preconditions"
if [ ! -d "/sys/module/$MODNAME" ]; then
    fail "$MODNAME is not loaded on the HOST -- ./run install"
    printf '        A container cannot load it: there is only one kernel, and it is the\n'
    printf '        host'"'"'s. The module has to be loaded out here for the client in there\n'
    printf '        to be able to use it.\n'
    exit 1
fi
pass "$MODNAME is loaded on the host"

command -v docker >/dev/null 2>&1 || { fail "docker is not installed"; exit 1; }
docker info >/dev/null 2>&1 || {
    fail "cannot talk to the docker daemon -- is it running, and are you in the docker group?"
    exit 1
}
docker compose version >/dev/null 2>&1 || { fail "the docker compose plugin is not installed"; exit 1; }
pass "docker and the compose plugin are usable"

# --- pki ----------------------------------------------------------------------
TMP="$(mktemp -d)"
chmod 755 "$TMP"
info "generating a throwaway CA and two certificates"
make_pki "$TMP" ||
    { fail "certificate generation failed"; sed 's/^/    /' "$TMP/openssl.log"; exit 1; }
pass "in $TMP -- bind-mounted read-only, deleted when this exits"

# --- the run ------------------------------------------------------------------
# --exit-code-from client makes the CLIENT's verdict the verdict: compose stops
# the server the moment the client is done and hands its exit status back. The
# server exiting first would otherwise leave the client hanging on a retry loop
# until something timed out.
info "docker compose up"
printf '\n'
PKI_DIR="$TMP" docker compose -f "$COMPOSE_DIR/docker-compose.yml" \
    up --build --abort-on-container-exit --exit-code-from client
rc=$?
printf '\n'

if [ "$rc" -eq 0 ]; then
    printf '\033[32m━━━ DCO WORKS IN A CONTAINER ━━━\033[0m\n\n'
    printf '  Two containers, one OpenVPN tunnel. The client negotiated a session\n'
    printf '  and moved its data channel into the HOST kernel'"'"'s ovpn-dco module --\n'
    printf '  which it can see and drive, but could never have installed.\n\n'
    printf '  Both containers, the network and the CA are gone.\n\n'
    exit 0
fi

fail "the client did not reach RESULT=PASS (exit $rc) -- its output is above"
exit 1
