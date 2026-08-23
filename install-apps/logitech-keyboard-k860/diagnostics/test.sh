#!/bin/bash

# Verify the K860 actually works over Bluetooth. Exits non-zero on failure.
# Read-only: never changes pairing state.

NAME_MATCH='k860|ergo'
fail=0
pass() { echo "  [ok]   $*"; }
bad()  { echo "  [FAIL] $*"; fail=1; }

echo "== bluez =="
systemctl is-active --quiet bluetooth && pass "bluetooth.service active" \
    || bad "bluetooth.service not active"

ver=$(bluetoothctl --version 2>/dev/null | awk '{print $2}')
case "$ver" in
    5.7[0-9]) bad "bluez $ver -- 5.72 cannot bond the K860; run 'make install'" ;;
    "")       bad "cannot determine bluez version" ;;
    *)        pass "bluez $ver" ;;
esac

echo "== adapter =="
[ "$(bluetoothctl show 2>/dev/null | grep -oP 'Powered: \K\w+')" = yes ] \
    && pass "powered" || bad "not powered"

# A deaf adapter makes every other result meaningless, so check it explicitly.
heard=$(bluetoothctl devices 2>/dev/null | grep -civE "$NAME_MATCH")
[ "$heard" -ge 2 ] && pass "hears $heard other BLE devices" \
    || bad "hears only $heard devices -- adapter may be deaf"

echo "== bond =="
MAC=$(bluetoothctl devices Bonded 2>/dev/null | grep -iE "$NAME_MATCH" | head -1 | cut -d ' ' -f 2)
if [ -z "$MAC" ]; then
    bad "no bonded K860 (run 'make pair')"
else
    pass "bonded at $MAC"
    bluetoothctl info "$MAC" | grep -q 'Trusted: yes' \
        && pass "trusted (reconnects after reboot)" || bad "not trusted"
    bluetoothctl info "$MAC" | grep -q 'Connected: yes' \
        && pass "connected" \
        || echo "  [note] not connected -- press channel 2 on the keyboard"
fi

echo "== input device =="
# tolower(), not IGNORECASE: Ubuntu's awk is mawk and ignores IGNORECASE.
# Requiring uhid distinguishes the Bluetooth keyboard from the dongle's.
if awk -v RS='' 'tolower($0) ~ /name=.*(k860|ergo)/ && tolower($0) ~ /sysfs=.*uhid/' \
     /proc/bus/input/devices | grep -q .; then
    pass "bluetooth keyboard registered (via uhid)"
elif grep -qiE "Name=.*($NAME_MATCH)" /proc/bus/input/devices; then
    bad "only a USB K860 present -- that is the dongle, not Bluetooth"
else
    echo "  [note] no input device; it appears on connect. Try:"
    echo "         bluetoothctl connect ${MAC:-<MAC>}"
fi

echo
[ $fail -eq 0 ] && echo "PASS" || echo "FAIL"
exit $fail
