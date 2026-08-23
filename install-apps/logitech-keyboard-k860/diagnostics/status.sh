#!/bin/bash

# Report the current state of the K860 Bluetooth setup. Read-only.

NAME_MATCH='k860|ergo'

# NOTE: IGNORECASE is a gawk extension and Ubuntu ships mawk, which ignores it
# silently. Always use tolower() here.
bt_input_present() {
    awk -v RS='' 'tolower($0) ~ /name=.*(k860|ergo)/ && tolower($0) ~ /sysfs=.*uhid/' \
        /proc/bus/input/devices | grep -q .
}

echo "bluez"
echo "  bluetoothd : $(bluetoothctl --version 2>/dev/null | awk '{print $2}')"
echo "  service    : $(systemctl is-active bluetooth 2>/dev/null)"
if [ -f /etc/systemd/system/bluetooth.service.d/override.conf ]; then
    echo "  source build: yes (systemd drop-in present)"
else
    echo "  source build: no (running distro bluez)"
fi

echo
echo "adapter"
echo "  powered    : $(bluetoothctl show 2>/dev/null | grep -oP 'Powered: \K\w+')"
echo "  blocked    : $(rfkill list bluetooth 2>/dev/null | grep -c 'blocked: yes') blocks"
heard=$(bluetoothctl devices 2>/dev/null | grep -civE "$NAME_MATCH")
echo "  hears      : $heard other BLE devices"
[ "$heard" -lt 2 ] && echo "               ^ possibly DEAF; scan results would be meaningless"

echo
echo "keyboard"
MAC=$(bluetoothctl devices Bonded 2>/dev/null \
      | grep -iE "$NAME_MATCH" | head -1 | cut -d ' ' -f 2)
if [ -z "$MAC" ]; then
    echo "  bonded     : NO   (run 'make pair')"
else
    echo "  address    : $MAC"
    for f in Bonded Trusted Connected; do
        printf '  %-11s: %s\n' "$(echo $f | tr A-Z a-z)" \
            "$(bluetoothctl info "$MAC" 2>/dev/null | grep -oP "^\s*$f: \K\w+")"
    done
    # The real proof of a bond is a key on disk, not what the UI claims.
    adapter=$(bluetoothctl show 2>/dev/null | head -1 | awk '{print $2}')
    if sudo -n grep -q 'LongTermKey' \
         "/var/lib/bluetooth/$adapter/$MAC/info" 2>/dev/null; then
        echo "  LTK on disk: yes"
    else
        echo "  LTK on disk: unknown (needs sudo) or MISSING"
    fi
fi

echo
echo "input device"
if bt_input_present; then
    echo "  bluetooth keyboard: PRESENT"
    awk -v RS='' 'tolower($0) ~ /name=.*(k860|ergo)/ && tolower($0) ~ /sysfs=.*uhid/' \
        /proc/bus/input/devices | grep -E 'N: Name=|H: Handlers=' | sed 's/^/    /'
elif grep -qiE "Name=.*($NAME_MATCH)" /proc/bus/input/devices; then
    echo "  bluetooth keyboard: NO -- but a USB one exists (the Unifying dongle)"
else
    echo "  bluetooth keyboard: NO"
fi

echo
echo "unifying dongle: $(lsusb 2>/dev/null | grep -qi unifying && echo 'plugged in' || echo 'not present')"
