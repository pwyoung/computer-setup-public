#!/bin/bash

# Build and install BlueZ from source into /usr/local, and point systemd at it.
#
# WHY: Pop!_OS 24.04 (noble) ships BlueZ 5.72, which cannot bond the Logitech
# ERGO K860 -- pairing dies with org.bluez.Error.AuthenticationCanceled. There is
# no newer bluez in the Pop/Ubuntu repos for noble, so it has to be built.
# 5.87 paired on the first attempt.
#
# The distro bluez package is left installed; this only overrides which binary
# systemd runs. See uninstall-bluez.sh to revert.

set -euo pipefail

BLUEZ_VERSION="${BLUEZ_VERSION:-5.87}"
SRC_URL="https://www.kernel.org/pub/linux/bluetooth/bluez-${BLUEZ_VERSION}.tar.xz"
BUILD_DIR="${BUILD_DIR:-/tmp/bluez-build-$$}"
DROPIN_DIR=/etc/systemd/system/bluetooth.service.d
PREFIX=/usr/local
BLUETOOTHD="$PREFIX/libexec/bluetooth/bluetoothd"

DEPS=(build-essential pkg-config libglib2.0-dev libdbus-1-dev libudev-dev
      libical-dev libreadline-dev libell-dev python3-docutils)

log() { echo "==> $*"; }

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user; it calls sudo where needed." >&2
    exit 1
fi

log "Current bluetoothd: $(bluetoothd --version 2>/dev/null || echo unknown)"

log "Installing build dependencies"
sudo apt-get update -qq
sudo apt-get install -y -qq "${DEPS[@]}"

log "Backing up the bond store (paired devices) to /var/backups"
sudo tar czf "/var/backups/bluetooth-bonds-$(date +%Y%m%d%H%M%S).tgz" \
    -C /var/lib bluetooth 2>/dev/null || true

log "Downloading bluez ${BLUEZ_VERSION}"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
curl -sSL --fail -O "$SRC_URL"
tar xf "bluez-${BLUEZ_VERSION}.tar.xz"
cd "bluez-${BLUEZ_VERSION}"

log "Configuring"
# --experimental matters: without it bluetoothd does not expose
# AdvertisementMonitorManager1 and logs "Unexpected NULL btd_adv_monitor_manager
# object", which the desktop Bluetooth UI relies on.
./configure \
    --prefix="$PREFIX" \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --enable-experimental \
    --enable-library \
    --disable-manpages

log "Building (this takes a few minutes)"
make -j"$(nproc)"

log "Installing to $PREFIX"
# NOTE: this also overwrites /usr/lib/systemd/system/bluetooth.service, which is
# owned by the distro bluez package. Reverting therefore needs a package
# reinstall, not just removing the drop-in. uninstall-bluez.sh does that.
sudo make install

log "Pointing systemd at the new bluetoothd"
sudo mkdir -p "$DROPIN_DIR"
sudo tee "$DROPIN_DIR/override.conf" >/dev/null <<EOF
# Use the locally built BlueZ instead of the distro build.
# Built by install-apps/logitech-keyboard-k860/bluez/build-bluez.sh
# Revert with that directory's uninstall-bluez.sh
[Service]
ExecStart=
ExecStart=$BLUETOOTHD --experimental
EOF

sudo systemctl daemon-reload
sudo systemctl restart bluetooth
sleep 3

log "Now running: $(bluetoothctl --version)"
systemctl is-active --quiet bluetooth && log "bluetooth.service active" \
    || { echo "bluetooth.service failed to start" >&2; exit 1; }

cat <<'MSG'

Done.

NOTE: restarting bluetoothd orphans desktop clients that were already running,
so the Bluetooth panel may show "off" until you log out or restart the panel
(e.g. `pkill -x cosmic-panel`). Bluetooth itself is fine -- check with
`bluetoothctl show`.
MSG
