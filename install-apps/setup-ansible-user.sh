#!/bin/bash

# Exit on error
set -e

if [[ $UID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

################################################################################
# OS Detection and Variable Setup
################################################################################

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

# Default hardware arch detection (mapped to sops/kubectl naming conventions)
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    HW="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    HW="arm64"
else
    HW=$ARCH
fi

################################################################################
# Package Installation
################################################################################

echo "Installing system packages..."

if [[ "$DISTRO_ID" =~ (debian|ubuntu|pop|kali) || "$DISTRO_LIKE" =~ (debian) ]]; then
    # --- DEBIAN / UBUNTU LOGIC ---
    SUDO_GROUP="sudo"

    export DEBIAN_FRONTEND=noninteractive

    apt-get update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        locales \
        openssh-server \
        python3 \
        python3-pip \
        python3-venv \
        bash-completion \
        sudo \
        wget \
        curl \
        gnupg \
        git \
        make \
        jq \
        sshpass \
        htop \
        tree \
        emacs-nox \
        nano \
        net-tools \
        iputils-ping

    # Locale generation for Debian
    locale-gen en_US.UTF-8
    update-locale LANG=en_US.UTF-8

elif [[ "$DISTRO_ID" =~ (rhel|centos|fedora|almalinux|rocky) || "$DISTRO_LIKE" =~ (rhel|fedora) ]]; then
    # --- RHEL / ROCKY / ALMA LOGIC ---
    SUDO_GROUP="wheel"

    # Install EPEL for packages like htop, sshpass, jq
    if ! rpm -q epel-release > /dev/null 2>&1; then
        dnf install -y epel-release
    fi

    # CRB (CodeReady Builder) is sometimes needed for dependencies on RHEL 9 clones
    # Trying to enable it gracefully if crb tool exists
    if command -v crb &> /dev/null; then crb enable; fi

    dnf install -y \
        openssh-server \
        python3 \
        python3-pip \
        bash-completion \
        sudo \
        wget \
        curl \
        gnupg \
        git \
        make \
        jq \
        sshpass \
        htop \
        tree \
        emacs-nox \
        nano \
        net-tools \
        iputils \
        glibc-langpack-en

    # Ensure python3-venv is present (sometimes separate in RHEL)
    dnf install -y python3-devel || true

    # Locale setting for RHEL
    localectl set-locale LANG=en_US.UTF-8
else
    echo "Unsupported distribution: $DISTRO_ID"
    exit 1
fi

# Common post-package cleanup
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
fi
passwd -l root

################################################################################
# Ansible user setup
################################################################################

echo "Setting up ansible user..."

USERNAME=ansible
USER_UID=1200
USER_GID=1200
SSH_PORT=2222

# Check if group exists, if not create it
if ! getent group $USERNAME > /dev/null; then
    groupadd -g $USER_GID $USERNAME
fi

# Check if user exists, if not create it
if ! id -u $USERNAME > /dev/null 2>&1; then
    useradd -m -u $USER_UID -g $USER_GID $USERNAME
fi

# Assign to sudo/wheel group
usermod -aG $SUDO_GROUP $USERNAME
usermod -d /home/$USERNAME $USERNAME
chsh -s /bin/bash $USERNAME

# Sudoers setup
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 0440 /etc/sudoers.d/$USERNAME

# Directory setup
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
touch /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
mkdir -p /home/$USERNAME/.ssh_host_keys
chown $USERNAME:$USERNAME /home/$USERNAME/.ssh_host_keys

# Host key generation
echo "Generating host keys..."
ssh-keygen -A -h
# We only generate these if they don't exist to prevent overwriting on re-runs
if [ ! -f /home/$USERNAME/.ssh_host_keys/ssh_host_rsa_key ]; then
    ssh-keygen -t rsa -f /home/$USERNAME/.ssh_host_keys/ssh_host_rsa_key -N ""
fi
if [ ! -f /home/$USERNAME/.ssh_host_keys/ssh_host_ecdsa_key ]; then
    ssh-keygen -t ecdsa -f /home/$USERNAME/.ssh_host_keys/ssh_host_ecdsa_key -N ""
fi
if [ ! -f /home/$USERNAME/.ssh_host_keys/ssh_host_ed25519_key ]; then
    ssh-keygen -t ed25519 -f /home/$USERNAME/.ssh_host_keys/ssh_host_ed25519_key -N ""
fi

chown $USERNAME:$USERNAME /home/$USERNAME/.ssh_host_keys/*

# Custom SSHD Config for User
SSH_CONFIG="/home/$USERNAME/.sshd_config"
cat <<EOF > $SSH_CONFIG
HostKey /home/$USERNAME/.ssh_host_keys/ssh_host_rsa_key
HostKey /home/$USERNAME/.ssh_host_keys/ssh_host_ecdsa_key
HostKey /home/$USERNAME/.ssh_host_keys/ssh_host_ed25519_key
Port $SSH_PORT
ListenAddress 0.0.0.0
PermitRootLogin no
PasswordAuthentication no
EOF

chown $USERNAME:$USERNAME $SSH_CONFIG
chmod 600 $SSH_CONFIG

# Git config
# Run as the user to ensure it goes to their home directory
sudo -u $USERNAME git config --global init.defaultBranch main

# Add SSH users
GITHUB_USERS="pwyoung"
# Clear file to avoid duplicates on re-run
echo "" > /home/$USERNAME/.ssh/authorized_keys
for user in $GITHUB_USERS; do \
    echo "# $user" >> /home/$USERNAME/.ssh/authorized_keys; \
    curl -s "https://github.com/$user.keys" >> /home/$USERNAME/.ssh/authorized_keys; \
done
chown $USERNAME:$USERNAME /home/$USERNAME/.ssh/authorized_keys

################################################################################
# Shell configuration
################################################################################

echo "Configuring shell..."

BASHRC="/home/$USERNAME/.bashrc"
# Only append if alias doesn't exist to prevent infinite growth on re-runs
if ! grep -q "alias ll='ls -alF'" $BASHRC; then
    echo "alias ll='ls -alF'" >> $BASHRC
    echo "alias la='ls -A'" >> $BASHRC
    echo "alias l='ls -CF'" >> $BASHRC
    echo "alias grep='grep --color=auto'" >> $BASHRC
    echo "alias ..='cd ..'" >> $BASHRC
    echo "alias ...='cd ../..'" >> $BASHRC
    echo "alias now='date +%Y-%m-%d_%H-%M-%S'" >> $BASHRC
    echo "if [ -f /etc/bash_completion ] && ! shopt -oq posix; then . /etc/bash_completion; fi" >> $BASHRC
    echo "if [ -d /etc/bash_completion.d ]; then for i in /etc/bash_completion.d/*; do if [ -f \$i ]; then . \$i; fi; done; unset i; fi" >> $BASHRC
fi


################################################################################
# Cleanup and Finish
################################################################################

chown -R $USERNAME:$USERNAME /home/$USERNAME
echo "Setup complete."
