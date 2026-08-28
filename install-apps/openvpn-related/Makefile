# OpenVPN Data Channel Offload (DCO) on Pop!_OS / Ubuntu 24.04.
# All targets delegate to ./run so the same commands work without make.

RUN := ./run

.PHONY: help status install test test-compose uninstall

help:
	@$(RUN) help

## Current state, read-only: kernel, module, openvpn, NetworkManager
status:
	@$(RUN) status

## Build and install the ovpn-dco-v2 DKMS module, load it, make it persist
install:
	@$(RUN) install

## Smoke test: stand up a real DCO tunnel in throwaway namespaces
test:
	@$(RUN) test

## The same proof with both ends as containers, via docker compose
test-compose:
	@$(RUN) test-compose

## Unload the module, stop it loading at boot, remove the package
uninstall:
	@$(RUN) uninstall
