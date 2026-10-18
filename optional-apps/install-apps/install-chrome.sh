#!/bin/bash

# 1. Check if Google Chrome is already installed
if command -v google-chrome &>/dev/null; then
    echo "Google Chrome is already installed."
    exit 0
fi

echo "Google Chrome not found. Detecting OS..."

# 2. Detect the OS and set variables
# Source the os-release file to get the ID (e.g., "ubuntu", "fedora", "rhel", "centos")
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "Cannot detect OS distribution. Exiting."
    exit 1
fi

# 3. logic based on the detected ID or ID_LIKE
if [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
    # --- DEBIAN / UBUNTU LOGIC ---
    echo "Debian/Ubuntu detected."
    FILE_NAME="google-chrome-stable_current_amd64.deb"
    URL="https://dl.google.com/linux/direct/$FILE_NAME"

    wget -q "$URL" -O "$FILE_NAME"

    echo "Installing Chrome via apt..."
    # Note: 'apt install ./file.deb' is preferred over 'dpkg -i'
    # as it resolves dependencies automatically.
    sudo apt-get update
    sudo apt-get install -y "./$FILE_NAME"

    rm "./$FILE_NAME"

elif [[ "$ID" == "rhel" || "$ID" == "fedora" || "$ID" == "centos" || "$ID_LIKE" == *"rhel"* || "$ID_LIKE" == *"fedora"* ]]; then
    # --- RHEL / FEDORA / CENTOS LOGIC ---
    echo "RHEL/Fedora detected."
    FILE_NAME="google-chrome-stable_current_x86_64.rpm"
    URL="https://dl.google.com/linux/direct/$FILE_NAME"

    wget -q "$URL" -O "$FILE_NAME"

    echo "Installing Chrome via dnf/yum..."
    # Check if dnf exists, otherwise fall back to yum
    if command -v dnf &>/dev/null; then
        sudo dnf install -y "./$FILE_NAME"
    else
        sudo yum localinstall -y "./$FILE_NAME"
    fi

    rm "./$FILE_NAME"

else
    echo "Unsupported distribution detected: $ID"
    exit 1
fi

echo "Google Chrome installation complete."
