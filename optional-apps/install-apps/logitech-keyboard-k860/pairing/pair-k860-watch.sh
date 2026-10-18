#!/bin/bash

# Pair a Logitech ERGO K860 over Bluetooth, watching for the keyboard to enter
# pairing mode instead of scanning once and giving up.
#
# WHY THIS EXISTS
# The plain scan-then-pair approach loses a race you cannot see: you long-press
# the channel key, the keyboard advertises for a limited window, and if the
# script is not already pairing when that happens, the window closes silently
# and you get "no passkey" with no clue why.
#
# This version holds ONE bluetoothctl session with a registered agent, scans
# continuously, and fires `pair` the instant the keyboard appears. You can
# long-press as many times as you like -- it will catch whichever attempt works.
#
# RUN IN A NORMAL TERMINAL so you can read the passkey.

BT_NAME_MATCH='k860|ergo'
CHANNEL="${1:-2}"
FIFO=$(mktemp -u /tmp/k860-btctl.XXXXXX)

cleanup() {
    exec 3>&- 2>/dev/null
    [ -n "$BTPID" ] && kill "$BTPID" 2>/dev/null
    rm -f "$FIFO"
}
trap cleanup EXIT

# Keep the screen from locking mid-pairing.
if [ -z "$K860_INHIBITED" ] && which systemd-inhibit >/dev/null; then
    export K860_INHIBITED=1
    exec systemd-inhibit --what=idle:sleep --who=K860pair \
        --why="pairing the K860" "$0" "$@"
fi

# A trusted-but-unbonded entry makes BlueZ auto-connect unencrypted and that
# blocks pairing. Always start clean.
stale=$(bluetoothctl devices | grep -iE "$BT_NAME_MATCH" | head -1 | cut -d ' ' -f 2)
if [ -n "$stale" ]; then
    echo "Clearing stale entry $stale ..."
    bluetoothctl untrust "$stale" >/dev/null 2>&1
    bluetoothctl remove  "$stale" >/dev/null 2>&1
fi

mkfifo "$FIFO"
bluetoothctl < "$FIFO" &     # output stays on your terminal, so you see the passkey
BTPID=$!
exec 3>"$FIFO"               # hold the write end open so the agent survives

echo "agent KeyboardDisplay" >&3
echo "default-agent"         >&3
echo "power on"              >&3
echo "scan on"               >&3

cat <<MSG

==================================================================
Now hold the "$CHANNEL" key on the K860 for a FULL 3 SECONDS,
until the LED BLINKS FAST.

  - A SHORT press only switches channel. It does NOT enter pairing
    mode, and produces no passkey. This is the usual failure.
  - If nothing happens, just long-press again. This script keeps
    watching and will grab it the moment it appears.

Waiting for the keyboard to start advertising (Ctrl-C to give up) ...
==================================================================

MSG

# The Intel adapter can silently go deaf: Discovering stays "yes" but it hears
# nothing at all. That looks EXACTLY like "the keyboard is not advertising" and
# sent this debug down a dead end for an hour. Prove the radio works first.
echo "Checking the adapter can actually hear other BLE devices ..."
heard=0
for i in $(seq 1 10); do
    heard=$(bluetoothctl devices | grep -cvi "$BT_NAME_MATCH")
    [ "$heard" -ge 2 ] && break
    sleep 2
done
if [ "$heard" -lt 2 ]; then
    # DO NOT power-cycle or hciconfig-reset the adapter here. Doing that leaves
    # the desktop Bluetooth panel showing "off" and orphans GUI clients, which
    # is far more annoying than a rescan. Just report it and let the user fix it
    # deliberately.
    echo
    echo "  The adapter appears DEAF: it heard only $heard other BLE devices."
    echo "  Any pairing result now would be meaningless, so stopping."
    echo
    echo "  Fix it yourself with ONE of these, then re-run:"
    echo "      bluetoothctl power off && bluetoothctl power on"
    echo "      sudo systemctl restart bluetooth"
    echo
    echo "  (Both briefly upset the desktop Bluetooth panel; reopen the"
    echo "   Settings window afterwards if it still shows off.)"
    exit 1
else
    echo "  OK, adapter hears $heard other devices."
fi

MAC=""
for i in $(seq 1 150); do    # ~5 minutes
    MAC=$(bluetoothctl devices | grep -iE "$BT_NAME_MATCH" | head -1 | cut -d ' ' -f 2)
    [ -n "$MAC" ] && break
    sleep 2
done

if [ -z "$MAC" ]; then
    echo
    echo "The keyboard never advertised."
    echo "It is powered on but not entering pairing mode. Check:"
    echo "  - power switch on the base is ON"
    echo "  - you are holding the key a full 3s and seeing a FAST blink"
    echo "  - battery is not flat (last known: 50%)"
    echo "  (the adapter was verified to be hearing other devices, so this"
    echo "   really is the keyboard staying silent, not a deaf radio)"
    exit 1
fi

echo
echo ">>> Keyboard is advertising at $MAC -- pairing now."
echo ">>> WATCH FOR:  Passkey: NNNNNN"
echo ">>> Type those digits ON THE K860 and press Enter. No echo."
echo
# Capture raw HCI so that if SMP fails we get the actual reason code instead
# of the useless "AuthenticationCanceled" that bluetoothctl reports.
HCI_CAP="/tmp/k860-hci-$$.btsnoop"
if sudo -n true 2>/dev/null; then
    sudo -n /usr/local/bin/btmon -w "$HCI_CAP" >/dev/null 2>&1 &
    BTMON_PID=$!
fi

# Stop the scan first: the [CHG]/RSSI spam can scroll the passkey off screen.
echo "scan off" >&3
sleep 1
echo "pair $MAC" >&3

# Give the passkey exchange room to complete.
for i in $(seq 1 45); do
    bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Bonded: yes' && break
    sleep 2
done

[ -n "$BTMON_PID" ] && { sudo -n kill "$BTMON_PID" 2>/dev/null; sleep 1; }

# After bonding, BlueZ re-keys the device object to the RESOLVED IDENTITY
# ADDRESS, which is not the address we saw advertising. Checking the old one
# reports "not bonded" for a pairing that actually succeeded. Re-resolve.
REAL_MAC="$MAC"
if ! bluetoothctl info "$MAC" 2>/dev/null | grep -q 'Bonded: yes'; then
    for cand in $(bluetoothctl devices Bonded 2>/dev/null | cut -d ' ' -f 2); do
        if bluetoothctl info "$cand" 2>/dev/null | grep -qiE "Name:.*($BT_NAME_MATCH)"; then
            REAL_MAC="$cand"; break
        fi
    done
fi
[ "$REAL_MAC" != "$MAC" ] && echo "Device re-keyed to identity address $REAL_MAC"

echo
echo "=== verification ==="

if bluetoothctl info "$REAL_MAC" 2>/dev/null | grep -q 'Bonded: yes'; then
    echo "  [ok]   BONDED  ($REAL_MAC)"
    # Bonded is the real success criterion. Trust it immediately so the bond
    # survives, BEFORE checking anything else.
    bluetoothctl trust "$REAL_MAC" >/dev/null 2>&1
    echo "  [ok]   trusted (reconnects after reboot)"

    # The HID input device is created via uhid a moment after connect, so give
    # it time. This is INFORMATIONAL ONLY -- never destroy a bond over it.
    got_input=0
    for i in $(seq 1 15); do
        if grep -qiE "Name=.*($BT_NAME_MATCH)" /proc/bus/input/devices; then
            # NOTE: IGNORECASE is a gawk extension. Ubuntu's awk is mawk, which
            # ignores it silently -- so a case-sensitive match against the
            # uppercase "ERGO K860" always failed. Use tolower() instead.
            if awk -v RS='' 'tolower($0) ~ /name=.*(k860|ergo)/ && tolower($0) ~ /sysfs=.*uhid/' \
                 /proc/bus/input/devices | grep -q .; then
                got_input=1; break
            fi
        fi
        sleep 2
    done
    if [ "$got_input" = 1 ]; then
        echo "  [ok]   keyboard input device present (via uhid)"
    else
        echo "  [note] no bluetooth input device yet -- the bond is fine."
        echo "         It usually appears on the next connect. Try:"
        echo "             bluetoothctl connect $REAL_MAC"
    fi

    echo
    echo "PAIRED. K860 bonded over Bluetooth on channel $CHANNEL ($REAL_MAC)."
    echo "Short-press $CHANNEL on the keyboard to use it here."
    [ -f "$HCI_CAP" ] && rm -f "$HCI_CAP"
    exit 0
fi

echo "  [FAIL] not bonded"
echo
echo "NOT removing anything -- a previous version of this script deleted"
echo "successful pairings by mistake. Inspect before cleaning up:"
echo "    bluetoothctl devices Bonded"
echo "    bluetoothctl info $MAC"
if [ -f "$HCI_CAP" ]; then
    echo
    echo "=== why SMP failed (raw HCI) ==="
    sudo -n /usr/local/bin/btmon -r "$HCI_CAP" 2>/dev/null \
        | grep -iE 'Pairing Failed|Encryption Change|New Long Term Key|Reason:' | head -20
    echo "Full capture: $HCI_CAP"
fi
exit 1
