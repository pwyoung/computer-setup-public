# BlueZ source build

Pop!_OS 24.04 (noble) ships **BlueZ 5.72**, which cannot bond the Logitech ERGO
K860. Pairing reaches SMP and then dies:

    Failed to pair: org.bluez.Error.AuthenticationCanceled
    hog-lib.c:info_read_cb() HID Information read failed:
        Request attribute has encountered an unlikely error

No newer bluez exists in the Pop/Ubuntu repos for noble (`apt-cache madison
bluez` shows only 5.72), so it has to be built. **5.87 paired on the first
attempt.**

Upstream [BlueZ issue #654](https://github.com/bluez/bluez/issues/654) reports
the same `AuthenticationCanceled` on 5.72 with a Logitech keyboard.

## Build

    ./build-bluez.sh              # defaults to 5.87
    BLUEZ_VERSION=5.86 ./build-bluez.sh

Installs to `/usr/local`, leaves the distro package installed, and adds a
systemd drop-in so `bluetooth.service` runs the new binary with
`--experimental`.

`--experimental` is required: without it bluetoothd does not expose
`AdvertisementMonitorManager1`, and logs
`Unexpected NULL btd_adv_monitor_manager object`.

## Revert

    ./uninstall-bluez.sh

This reinstalls the distro `bluez` package as well as removing the drop-in,
because `make install` overwrites `/usr/lib/systemd/system/bluetooth.service`,
which the package owns.

## Known side effect

Restarting `bluetoothd` orphans desktop clients already connected to the old
one, so the Bluetooth panel can show "off" until you log out or restart it
(`pkill -x cosmic-panel`). Bluetooth itself is unaffected — confirm with
`bluetoothctl show`.
