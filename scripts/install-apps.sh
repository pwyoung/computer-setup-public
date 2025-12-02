#!/bin/bash

set -e

# Detect OS
# ------------------------------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    DISTRO_ID=$ID
    DISTRO_LIKE=$ID_LIKE
else
    echo "Cannot detect OS. Exiting."
    exit 1
fi

echo "Detected OS: $OS ($DISTRO_ID)"

# Define Packages
# ------------------------------------------------------------------------------
# Packages common to both families
PKGS="emacs-nox tree dmidecode iotop openssh-server python3-pip jq bash-completion pass ruby"

# Distro-specific logic
if [[ "$DISTRO_ID" == "ubuntu" ]] || [[ "$DISTRO_ID" == "debian" ]] || [[ "$DISTRO_LIKE" == *"debian"* ]]; then
    PKG_MANAGER="apt"
    # Ubuntu splits venv into a separate package
    PKGS+=" python3-venv"
    # These are standard in Ubuntu repos
    PKGS+=" glances htop haveged"

elif [[ "$DISTRO_LIKE" == *"rhel"* ]] || [[ "$DISTRO_ID" == "fedora" ]] || [[ "$DISTRO_ID" == "centos" ]]; then
    PKG_MANAGER="dnf"

    # RHEL/CentOS/Rocky/Alma need EPEL enabled for htop, glances, haveged
    if [[ "$DISTRO_ID" != "fedora" ]]; then
        echo "Ensuring EPEL repository is installed for RHEL-derivatives..."
        sudo dnf install -y epel-release
    fi

    # 'python3-venv' is usually built into the main python libs on RHEL,
    # so we don't add it explicitly.
    PKGS+=" glances htop haveged"
else
    echo "Unsupported distribution family."
    exit 1
fi

# Functions
# ------------------------------------------------------------------------------

install_packages() {
    echo "Installing packages using $PKG_MANAGER..."

    if [ "$PKG_MANAGER" == "apt" ]; then
        sudo apt update
        # DEBIAN_FRONTEND=noninteractive prevents prompts hanging the script
        sudo DEBIAN_FRONTEND=noninteractive apt install -y $PKGS
        sudo apt autoremove -y
    elif [ "$PKG_MANAGER" == "dnf" ]; then
        # dnf update is not strictly required before install, but good practice
        sudo dnf install -y $PKGS
        sudo dnf autoremove -y
    fi
}

apps() {
    D=./install-apps
    SEP="################################################################################"

    # Check if directory exists and is not empty
    if [ -d "$D" ] && ls "$D"/*.sh 1> /dev/null 2>&1; then
        # Use globbing instead of $(ls) to handle spaces in filenames safely
        for i in "$D"/*.sh; do
            echo ""
            echo "$SEP"
            echo "Run $i"
            echo "$SEP"
            bash "$i"
        done
    else
        echo "No scripts found in $D or directory does not exist. Skipping."
    fi
}

main() {
    install_packages
    apps
}

main
