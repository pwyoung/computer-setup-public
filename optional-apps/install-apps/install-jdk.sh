#!/bin/bash

# Shell script to install OpenJDK on Debian-based and RHEL-based systems.
# This script installs OpenJDK 21 (LTS version) by default.
# It will automatically re-run with sudo if not executed as root.

set -e  # Exit on error

# Check if running as root; if not, re-execute with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Re-running with sudo..."
    exec sudo "$0" "$@"
    exit $?
fi

JDK_VERSION="21"  # Change this to install a different version, e.g., "17"

# Function to detect the distribution family
detect_distro() {
    if [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "Unsupported distribution. This script supports Debian-based (e.g., Ubuntu) and RHEL-based (e.g., CentOS, Fedora) systems."
        exit 1
    fi
}

DISTRO=$(detect_distro)

if [ "$DISTRO" = "debian" ]; then
    echo "Detected Debian-based system. Installing OpenJDK $JDK_VERSION using apt..."
    apt update -y
    apt install -y openjdk-${JDK_VERSION}-jdk
elif [ "$DISTRO" = "rhel" ]; then
    echo "Detected RHEL-based system. Installing OpenJDK $JDK_VERSION..."
    # Check for dnf (RHEL 8+, Fedora) or yum (RHEL 7, CentOS 7)
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi
    $PKG_MANAGER install -y java-${JDK_VERSION}-openjdk-devel
fi

# Verify installation
java -version
echo "OpenJDK $JDK_VERSION installed successfully."


