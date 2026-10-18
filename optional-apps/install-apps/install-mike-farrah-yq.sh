#!/bin/bash

# ==========================================
# Script to install Mike Farah's yq on Linux
# Supports: Ubuntu/Debian & RHEL/CentOS/Fedora
# ==========================================

set -e

# 1. Check for Root Privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# 2. Detect Operating System and Install Dependencies (wget)
echo "Detecting OS..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
else
    OS=$(uname -s)
fi

echo "OS detected: $OS"

# Install wget if missing, based on package manager
if ! command -v wget &> /dev/null; then
    echo "wget not found. Installing..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y wget
    elif command -v dnf &> /dev/null; then
        dnf install -y wget
    elif command -v yum &> /dev/null; then
        yum install -y wget
    else
        echo "Error: Package manager not found. Please install 'wget' manually."
        exit 1
    fi
fi

# 3. Detect Architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        BINARY="yq_linux_amd64"
        ;;
    aarch64)
        BINARY="yq_linux_arm64"
        ;;
    armv7l)
        BINARY="yq_linux_arm"
        ;;
    i386|i686)
        BINARY="yq_linux_386"
        ;;
    *)
        echo "Error: Unsupported architecture $ARCH"
        exit 1
        ;;
esac

echo "Architecture detected: $ARCH (Binary: $BINARY)"

# 4. Download and Install yq
DOWNLOAD_URL="https://github.com/mikefarah/yq/releases/latest/download/$BINARY"
INSTALL_PATH="/usr/local/bin/yq"

echo "Downloading $BINARY from $DOWNLOAD_URL..."
wget -qO "$INSTALL_PATH" "$DOWNLOAD_URL"

# 5. Set Permissions
chmod +x "$INSTALL_PATH"

# 6. Verify Installation
if command -v yq &> /dev/null; then
    VERSION=$(yq --version)
    echo "-----------------------------------"
    echo "Success! yq installed to $INSTALL_PATH"
    echo "Version: $VERSION"
    echo "-----------------------------------"
else
    echo "Error: Installation failed."
    exit 1
fi
