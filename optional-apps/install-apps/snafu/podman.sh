#!/usr/bin/env bash
# =============================================================================
# Script: switch-from-docker-to-podman-on-pop-os.sh
# Purpose: Remove/disable Docker CE → Install latest Podman → Set up drop-in replacement
#          Optionally install Podman Desktop (native, no VM overhead on Linux)
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ──────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ──────────────────────────────────────────────────────────────────────────────

function print_header() {
    echo -e "\n${GREEN}==> $1${NC}"
}

function print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

function print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

function check_command() {
    command -v "$1" >/dev/null 2>&1
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 1: Stop and disable Docker services (safer than purge in most cases)
# ──────────────────────────────────────────────────────────────────────────────
function disable_docker() {
    print_header "Disabling and stopping Docker CE (if present)"

    if systemctl is-active --quiet docker; then
        print_info "Stopping docker service..."
        sudo systemctl stop docker docker.socket || true
    fi

    if systemctl is-enabled --quiet docker; then
        print_info "Disabling docker service..."
        sudo systemctl disable docker docker.socket || true
    fi

    # Also stop containerd if running
    if systemctl is-active --quiet containerd; then
        sudo systemctl stop containerd || true
    fi

    print_info "Docker services stopped and disabled."
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 2: Remove Docker CE packages (optional aggressive removal)
# ──────────────────────────────────────────────────────────────────────────────
function remove_docker_packages() {
    set +e

    print_header "Removing Docker CE packages"

    local packages=(
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        docker-ce-rootless-extras
    )

    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "$pkg"; then
            print_info "Removing $pkg..."
            sudo apt-get remove --purge -y "$pkg"
        fi
    done

    print_info "Cleaning up leftover files..."
    sudo rm -rf /var/lib/docker /etc/docker /var/run/docker.sock

    #PWY Added
    sudo apt remove -y podman buildah skopeo
    sudo apt remove -y docker-buildx-plugin docker-compose-plugin docker-compose
    PKGS=$(sudo apt list  --installed 2>/dev/null | grep -iE 'docker|podman' | awk '{print $1}' | cut -d '/' -f 1)
    if [ "x$PKGS" == "x" ]; then
        echo "All packages removed"
    else
        echo "PACKAGES TO DELETE: $PKGS"
        sudo apt remove -y $PKGS
    fi

    echo "Cleanup packages"
    sudo apt-get autoremove -y
    sudo apt-get autoclean

    print_info "Docker and Podman packages removed."
    #read -p "hit enter"

    set -e
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 3: Install latest Podman (from official Ubuntu/Pop!_OS compatible repo)
# ──────────────────────────────────────────────────────────────────────────────
function install_podman() {
    print_header "Installing latest stable Podman"


    # Update and install prerequisites
    # Fail if the apt system (keys or repos) are corrupt at this point
    sudo apt update
    sudo apt install -y software-properties-common

    # OS version
    VERSION_ID=$(lsb_release -rs)


    if [ ! -e /etc/apt/trusted.gpg.d/libcontainers.gpg ]; then
        echo "Download the GPG APT key"
        curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/libcontainers.gpg > /dev/null
        sudo apt update
        echo "Added the key"
        read -p "hit enter"
    fi

    if [ ! -e /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list ]; then
        echo "Add repo and update packages"
        echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
        sudo apt update
        read -p "hit enter"
    fi

    if ! command -v podman; then
        echo "Install podman"
        sudo apt install podman -y
        #sudo apt install -y podman podman-docker buildah skopeo fuse-overlayfs
        read -p "hit enter"
    fi

    echo "Verify"
    podman --version
    read -p "hit enter"

    #print_info "Ensuring user namespaces are enabled..."
    #if ! grep -q "user.max_user_namespaces" /etc/sysctl.conf; then
    #    echo "user.max_user_namespaces = 28633" | sudo tee -a /etc/sysctl.conf
    #    sudo sysctl -p
    #fi

}

# ──────────────────────────────────────────────────────────────────────────────
# Step 4: Set up docker → podman alias + docker-compose compatibility
# ──────────────────────────────────────────────────────────────────────────────
function setup_drop_in_replacement() {
    print_header "Setting up Podman as docker drop-in replacement"

    D=~/bin
    if [ ! -e "$D" ]; then
        mkdir "$D"
        echo "Add $D to PATH"
        read -p "Hit enter when done"
    fi

    F="$D/docker"

    cat <<EOF >"$F"
#!/bin/bash


if ! command -v podman &>/dev/null; then
    exec /usr/bin/docker "$@"
fi

# Intercept "compose" to use the official plugin with Podman's socket.
# All other commands are passed directly to podman.
if [[ "$1" == "compose" ]]; then
    # Remove "compose" from the argument list
    shift

    # Ensure socket is running (idempotent)
    systemctl --user start podman.socket

    # Point DOCKER_HOST to Podman's socket just for this command
    # Note: Ensure the socket is active via: systemctl --user enable --now podman.socket
    export DOCKER_HOST="unix:///run/user/$UID/podman/podman.sock"

    # Execute the official docker-compose plugin binary
    # We use 'exec' to replace the current shell process with the command
    exec /usr/libexec/docker/cli-plugins/docker-compose "$@"
else
    # Pass all original arguments to podman
    exec podman "$@"
fi

EOF

    chmod 0700 "$F"

}

# ──────────────────────────────────────────────────────────────────────────────
# Step 5: Install Podman Desktop (native, no VM overhead on Linux)
# ──────────────────────────────────────────────────────────────────────────────
function install_podman_desktop() {
    print_header "Installing Podman Desktop (native GUI)"

    if check_command podman-desktop; then
        print_info "Podman Desktop is already installed."
        return
    fi

    print_info "Downloading latest Podman Desktop .deb (as of 2025)..."
    local deb_url="https://github.com/podman-desktop/podman-desktop/releases/latest/download/podman-desktop-1.14.0.deb"
    # Note: replace version above with actual latest from https://podman-desktop.io/downloads

    local tmp_deb="/tmp/podman-desktop.deb"
    curl -L -o "$tmp_deb" "$deb_url" || print_error "Failed to download Podman Desktop"

    print_info "Installing Podman Desktop..."
    sudo apt install -y "$tmp_deb"

    rm -f "$tmp_deb"

    print_info "Podman Desktop installed. Launch with: podman-desktop"
}

# ──────────────────────────────────────────────────────────────────────────────
# Main execution
# ──────────────────────────────────────────────────────────────────────────────
run() {
    print_header "Switching from Docker CE to Podman on Pop!_OS"

    disable_docker
    remove_docker_packages           # comment this line if you want to keep config files
    install_podman
    setup_drop_in_replacement

    # Optional: install Podman Desktop (uncomment if you want the GUI)
    #install_podman_desktop

    print_header "Done!"
    echo -e "${GREEN}Podman is now ready to use as 'docker'${NC}"
    echo "Run 'source ~/.bashrc' (or ~/.zshrc) to activate the alias immediately."
    echo "Test with: docker --version   (should show podman)"
    echo "           docker run hello-world"



    # PWY ADDED
    #sudo apt update && sudo apt install containernetworking-plugins
    # see ~/bin/docker
}

#run
#install_podman


echo "SNAFU: Ubuntu has 3.4.x of podman, but Podman is on 4.6.x"
echo "GIVE UP ALREADY RUNNING PODMAN ON UBUTU..."
disable_docker
remove_docker_packages           # comment this line if you want to keep config files
