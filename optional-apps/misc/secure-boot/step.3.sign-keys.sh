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

    #sbctl status | grep 'Setup Mode' | grep 'Disabled'
    #sbctl status | grep 'Secure Boot' | grep 'Disabled'

    # Example:
    # 1. Sign the systemd-boot bootloader
    #sbctl sign /boot/efi/EFI/systemd/systemd-bootx64.efi
    # 2. Sign the current kernel (vmlinuz.efi)
    #sbctl sign
    # 3. Sign the previous kernel (vmlinuz-previous.efi)
    #sbctl sign /boot/efi/EFI/Pop_OS-316874df-0533-4382-99d9-a7376f2b8474/vmlinuz-previous.efi
    # 4. Sign the recovery kernel
    #sbctl sign /boot/efi/EFI/Recovery-10EB-8003/vmlinuz.efi


    SEARCH_DIR="/boot/efi/EFI"

    FILES=$(find /boot/efi/EFI -type f -name "BOOTX64.EFI" -o -name "systemd-bootx64.efi" -o -name "vmlinuz.efi" -o -name "vmlinuz-previous.efi")
    echo "FILES=$FILES"

    SEP="################################################################################"
    while IFS= read -r FILE; do
        echo "$SEP"
        echo "Sign file: $FILE"
        sbctl sign $FILE
    done <<< "$FILES"

}

run_sbctl
