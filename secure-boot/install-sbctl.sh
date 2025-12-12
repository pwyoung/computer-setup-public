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


install_sbctl() {
    if command -v sbctl &>/dev/null; then
        echo "sbctl is installed"
        return
    fi

    if command -v go &>/dev/null; then
        echo "go is installed"
    else
        echo "Install Go (Go Language)"
        exit 1
    fi


    # https://github.com/Foxboron/sbctl
    go install github.com/foxboron/sbctl/cmd/sbctl@latest
    sudo mv $HOME/go/bin/sbctl /usr/bin/
}

install_sbctl
