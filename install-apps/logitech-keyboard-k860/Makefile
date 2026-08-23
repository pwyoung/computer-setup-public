# Logitech ERGO K860 over Bluetooth.
# All targets delegate to ./run so the same commands work without make.

RUN := ./run

.PHONY: help install pair test status uninstall

help:
	@$(RUN) help

## Build and install BlueZ from source (Pop!_OS 24.04 ships 5.72, too old)
install:
	@$(RUN) install

## Pair the keyboard. CHANNEL=3 to use Easy-Switch channel 3.
## Needs a terminal: the passkey is shown briefly and typed on the keyboard.
pair:
	@$(RUN) pair $(CHANNEL)

## Verify it actually works (non-zero exit on failure)
test:
	@$(RUN) test

## Show current state, read-only
status:
	@$(RUN) status

## Revert to the distro BlueZ
uninstall:
	@$(RUN) uninstall
