#!/bin/bash

################################################################################
# Boiler Plate: trap errors
################################################################################
set -eE

# Define a function to handle errors
error_handler() {
  local exit_status=$?
  local line_number=$LINENO
  local command_failed=$BASH_COMMAND
  echo "ERROR: Command '$command_failed' failed with exit status $exit_status at line $line_number." >&2
  exit 1 # Exit the script with a non-zero status
}

# Set the trap for the ERR signal to call the error_handler function
trap 'error_handler' ERR

################################################################################

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root (e.g. via sudo)." >&2
  exit 1
fi


run_sbctl() {
    export PATH=$PATH:/usr/local/go/bin

    if ! command -v sbctl &>/dev/null; then
        echo "sbctl is not installed..."
        return
    fi


    sbctl verify | grep 'is signed'

    if sbctl verify | grep 'is not signed'; then
        echo "Sign this file"
        exit 1
    fi

    cat <<EOF
    NEXT: Enable Secure Boot in UEFI

    Since your system is now configured, the final step is to enable Secure Boot in your computer's UEFI/BIOS settings.

    Reboot your machine.

    Press the key to enter your UEFI/BIOS Setup (usually F2, F10, F12, or Del).

    Navigate to the Security or Boot section.

    Find and Enable Secure Boot.

    Save and Exit.
EOF
}

run_sbctl
