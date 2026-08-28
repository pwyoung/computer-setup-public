#!/bin/bash
#
# lib-certs.sh -- a throwaway CA and one server/client pair, for the tests.
#
# Sourced by both scripts/smoke-test.sh and scripts/compose-test.sh. It is
# shared rather than copied because of the keyUsage lesson below: a second copy
# would be the one that quietly loses it.

# make_pki DIR
#
# Leaves ca.crt/ca.key, server.crt/server.key and client.crt/client.key in DIR,
# plus openssl.log. Non-zero on failure, with the reason in that log.
#
# remote-cert-tls server on the client checks BOTH keyUsage and the serverAuth
# extendedKeyUsage. Setting only the EKU gets "VERIFY KU ERROR" and a failed
# handshake -- which reads like a DCO problem and is not one.
#
# One day of validity: these exist for the length of a test run and must never
# be mistaken for something worth keeping.
make_pki() {
    local dir="$1" who KU EKU
    {
        openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
            -keyout "$dir/ca.key" -out "$dir/ca.crt" -subj "/CN=dco-test-ca" || return 1
        for who in server client; do
            if [ "$who" = server ]; then
                KU="digitalSignature,keyEncipherment"; EKU="serverAuth"
            else
                KU="digitalSignature"; EKU="clientAuth"
            fi
            openssl req -newkey rsa:2048 -nodes \
                -keyout "$dir/$who.key" -out "$dir/$who.csr" -subj "/CN=dco-test-$who" || return 1
            printf 'basicConstraints=CA:FALSE\nkeyUsage=%s\nextendedKeyUsage=%s\n' \
                "$KU" "$EKU" > "$dir/$who.ext"
            openssl x509 -req -in "$dir/$who.csr" -CA "$dir/ca.crt" -CAkey "$dir/ca.key" \
                -CAcreateserial -out "$dir/$who.crt" -days 1 -extfile "$dir/$who.ext" || return 1
        done
    } >"$dir/openssl.log" 2>&1
}
