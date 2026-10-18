#!/bin/bash

# Revert to the distro BlueZ built by the bluez package.
#
# `make install` from the source build overwrote
# /usr/lib/systemd/system/bluetooth.service, which the distro package owns, so
# removing the systemd drop-in alone is NOT enough -- the package has to be
# reinstalled to restore that file.

set -euo pipefail

DROPIN_DIR=/etc/systemd/system/bluetooth.service.d

echo "==> Removing systemd drop-in"
sudo rm -rf "$DROPIN_DIR"

echo "==> Reinstalling distro bluez (restores the unit file the build replaced)"
sudo apt-get install --reinstall -y bluez

echo "==> Restarting"
sudo systemctl daemon-reload
sudo systemctl restart bluetooth
sleep 2

echo "==> Now running: $(bluetoothctl --version)"
echo
echo "The binaries built into /usr/local are left in place and unused."
echo "Remove them too if you want:"
echo "    sudo rm -f  /usr/local/bin/bluetoothctl /usr/local/bin/btmon"
echo "    sudo rm -rf /usr/local/libexec/bluetooth"
echo
echo "Paired devices are untouched (they live in /var/lib/bluetooth)."
