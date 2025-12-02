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

LOG=/tmp/sbctl.log


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


    # This always shows an error/problem
    #sbctl setup --migrate


    cat <<EOF >/dev/null
    sbctl status
    should show:

    Setup Mode:      Enabled
    Secure Boot:     Disabled

    If it shows Enabled, you can proceed with the key enrollment:
    Bash

    sudo sbctl enroll-keys --microsoft
EOF
    sbctl status | grep 'Setup Mode' | grep 'Enabled'
    sbctl status | grep 'Secure Boot' | grep 'Disabled'


    # FIRST TIME
    #
    # Enroll keys (including windows)
    #sbctl enroll-keys --microsoft
    #Your system is not in Setup Mode! Please reboot your machine and reset secure boot keys before attempting to enroll the keys.
    # reboot
    # Secure boot: <was off>
    # Secure boot mode: Enabled Custom mode
    # Secure boot: keys -> saved to usb file, then DELETED ALL KEYS
    # reboot


    # After clearing keys
    #
    sbctl enroll-keys --microsoft | tee $LOG
    #old configuration detected. Please use `sbctl setup --migrate`
    #Enrolling keys to EFI variables...
    #With vendor keys from microsoft...✓
    #Enrolled keys to the EFI variables!
    cat $LOG | grep 'Enrolled keys'
}

run_sbctl
