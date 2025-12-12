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



    # Create keys
    sbctl create-keys
    # Created Owner UUID 3784ceb2-7ca7-4809-b14d-4e073c1313ce
    # ✓ Secure boot keys have already been created!
}

run_sbctl

