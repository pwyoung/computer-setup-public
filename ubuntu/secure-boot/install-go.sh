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

install_go() {
    if command -v go &>/dev/null; then
        echo "go is installed"
        return
    fi

    sudo apt update
    sudo apt install build-essential libpcsclite-dev

    # v1.18
    #
    #sudo apt install golang-go
    #sudo apt remove golang-go

    # v1.21
    #
    # https://go.dev/dl/
    cd ~/Downloads
    wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
    rm go1.21.5.linux-amd64.tar.gz

    # Put equivalent of this in ~/.profile.d/golang.sh
    #export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
}


install_go

