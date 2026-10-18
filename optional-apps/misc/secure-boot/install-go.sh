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

GO_VERSION="1.21.5"
GO_FILE="go${GO_VERSION}.linux-amd64.tar.gz"

install_go() {
    # 1. Check if Go is already installed
    if command -v go &>/dev/null; then
        echo "go is installed"
        return
    fi

    echo "Installing dependencies..."

    # 2. Detect OS/Package Manager and install prerequisites
    if command -v apt-get &>/dev/null; then
        # Ubuntu / Debian
        echo "Detected 'apt'. Running Ubuntu setup..."
        sudo apt update
        sudo apt install -y build-essential libpcsclite-dev wget tar
    elif command -v dnf &>/dev/null; then
        # Modern RHEL / CentOS / Fedora
        echo "Detected 'dnf'. Running RHEL setup..."
        sudo dnf groupinstall -y "Development Tools"
        sudo dnf install -y pcsc-lite-devel wget tar
    elif command -v yum &>/dev/null; then
        # Older RHEL / CentOS
        echo "Detected 'yum'. Running RHEL setup..."
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y pcsc-lite-devel wget tar
    else
        echo "Error: Neither apt, dnf, nor yum found. Cannot install dependencies."
        return 1
    fi

    # 3. Download and Install Go (Generic Linux logic)

    # Use /tmp to ensure the directory exists on servers/headless machines
    cd /tmp || return

    echo "Downloading Go ${GO_VERSION}..."
    if wget "https://go.dev/dl/${GO_FILE}"; then
        echo "Extracting..."
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "${GO_FILE}"
        rm "${GO_FILE}"
        echo "Go installed successfully to /usr/local/go"
    else
        echo "Download failed."
        return 1
    fi

    # Reminder for PATH
    echo "------------------------------------------------"
    echo "Make sure to add Go to your PATH if you haven't yet:"
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin'
    echo "------------------------------------------------"
}

install_go
