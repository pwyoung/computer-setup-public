# Logitech ERGO K860 over Bluetooth

Pair the K860 directly to the laptop's Bluetooth radio, so the Unifying USB
dongle is not needed.

**Status: working** (2026-08-22, Pop!_OS 24.04, channel 2, no dongle).

    make status     # current state, read-only
    make test       # verify it works; non-zero exit on failure
    make install    # build + install BlueZ from source (one time)
    make pair       # pair the keyboard   (make pair CHANNEL=3)
    make uninstall  # revert to distro BlueZ

Every target just calls `./run <command>`, which also works standalone.

First-time setup:

    make install && make pair && make test

## Layout

    Makefile              thin wrapper over ./run
    run                   command dispatcher
    bluez/                source build of BlueZ 5.87 + revert script
    pairing/              the pairing script
    diagnostics/          status.sh (read-only) and test.sh (pass/fail)

## Solaar is not used

Solaar only speaks Logitech's proprietary HID++ over the **Unifying/Bolt USB
receiver**. It cannot pair or manage Bluetooth devices — that is BlueZ's job.
It was useful once here, for reading the keyboard's Easy-Switch host slots while
debugging, and is otherwise irrelevant to this setup. The `solaar` apt package
has been removed.

If you ever want that diagnostic view back (`solaar show` lists which of the
keyboard's 3 channels are paired), reinstall it and plug the dongle in:

    sudo apt install solaar

## The one thing that actually blocked this

**Pop!_OS 24.04 ships BlueZ 5.72, which cannot bond this keyboard.** Pairing
reaches SMP and dies with `org.bluez.Error.AuthenticationCanceled`. There is no
newer bluez in the repos for noble. Building **5.87** fixed it on the first
attempt. See `bluez/README.md`.

## Using it

- Long-press an Easy-Switch key (**1/2/3**) for a full **3 seconds** until the
  LED blinks **fast**. Fast blinking *is* pairing mode; nothing blinks slowly.
  A short press only switches channel and looks almost identical.
- Short-press a channel key to switch between the dongle and Bluetooth.
- `bluetoothctl connect` fails with `le-connection-abort-by-local` while a scan
  is running. Stop scanning first.

## Verification traps

Three separate checks reported FAILURE on a pairing that had actually
SUCCEEDED, and an earlier version of the script then "cleaned up" by deleting
the good bond. Worth knowing before writing any check like these:

| Trap | Why it lied |
|---|---|
| `Connected: yes` | Connecting is not bonding. Require `Bonded: yes` **and** `[LongTermKey]` on disk. |
| Matching the input device by name | The Unifying dongle also creates one named `Logitech ERGO K860`. Require `Sysfs=*uhid*`. |
| `awk -v IGNORECASE=1` | gawk-only. Ubuntu ships **mawk**, which ignores it silently, so `/k860/` never matched `"ERGO K860"`. Use `tolower($0) ~ /.../`. |
| Checking the advertising address | After bonding BlueZ re-keys the device to its resolved **identity address** (`…B5` advertised, `…B6` bonded). Re-resolve via `bluetoothctl devices Bonded`. |

Rules the scripts follow as a result:

- `Bonded: yes` is the only success criterion, and `trust` runs immediately on it.
- The input-device check is **informational** and can never destroy a bond.
- Nothing calls `remove`/`untrust` on failure.
- Nothing power-cycles the adapter — that breaks the desktop Bluetooth panel.

## Two sources of false negatives

- **The adapter goes deaf.** `Discovering: yes` while hearing nothing at all.
  This invalidated a whole round of testing. `make status` reports how many
  other BLE devices it hears; the pairing script refuses to run below 2.
  Fix with `bluetoothctl power off && bluetoothctl power on`.
- **Restarting bluetoothd orphans desktop clients.** The COSMIC panel keeps
  showing "off" until it is restarted (`pkill -x cosmic-panel`) or you log out.
  Bluetooth itself is fine; check `bluetoothctl show`.

## References

- [Getting Started - ERGO K860](https://support.logi.com/hc/en-001/articles/360041797553-Getting-Started-ERGO-K860)
- [BlueZ #654 — AuthenticationCanceled on 5.72 with a Logitech keyboard](https://github.com/bluez/bluez/issues/654)
