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
    print_header "Removing Docker CE packages"

    local packages=(
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        docker-ce-rootless-extras
    )

    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "$pkg"; then
            print_info "Removing $pkg..."
            sudo apt-get remove --purge -y "$pkg" || true
        fi
    done

    print_info "Cleaning up leftover files..."
    sudo rm -rf /var/lib/docker /etc/docker /var/run/docker.sock || true

    #PWY Added
    for i in ; do echo python3-dockerpty; sudo apt remove -f python3-dockerpty ;done


    
    sudo apt-get autoremove -y
    sudo apt-get autoclean

    print_info "Docker CE packages removed."
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 3: Install latest Podman (from official Ubuntu/Pop!_OS compatible repo)
# ──────────────────────────────────────────────────────────────────────────────
function install_podman() {
    print_header "Installing latest stable Podman"

    # Add official Podman repository (recommended for up-to-date versions)
    if ! grep -q "devel:kubic:libcontainers:stable" /etc/apt/sources.list.d/*; then
        print_info "Adding Podman stable repository..."
        echo 'deb [signed-by=/usr/share/keyrings/devel_kubic_libcontainers_stable-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_22.04/ /' \
            | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

        curl -fsSL https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_22.04/Release.key \
            | sudo gpg --dearmor -o /usr/share/keyrings/devel_kubic_libcontainers_stable-archive-keyring.gpg
    fi

    print_info "Updating package lists..."
    sudo apt update

    print_info "Installing Podman and friends..."
    sudo apt install -y podman podman-docker buildah skopeo fuse-overlayfs

    # Enable user namespaces (required for rootless)
    print_info "Ensuring user namespaces are enabled..."
    if ! grep -q "user.max_user_namespaces" /etc/sysctl.conf; then
        echo "user.max_user_namespaces = 28633" | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p
    fi

    print_info "Podman installed successfully."
}

# ──────────────────────────────────────────────────────────────────────────────
# Step 4: Set up docker → podman alias + docker-compose compatibility
# ──────────────────────────────────────────────────────────────────────────────
function setup_drop_in_replacement() {
    print_header "Setting up Podman as docker drop-in replacement"

    # Create user alias in shell profile (persistent)
    local profile="$HOME/.bashrc"
    [[ -f "$HOME/.zshrc" ]] && profile="$HOME/.zshrc"

    if ! grep -q "alias docker=podman" "$profile"; then
        print_info "Adding docker alias to $profile"
        {
            echo ""
            echo "# Podman as docker drop-in"
            echo "alias docker=podman"
            echo "alias docker-compose='podman-compose'"
        } >> "$profile"
    fi

    # Install podman-compose (python-based, most compatible)
    if ! check_command podman-compose; then
        print_info "Installing podman-compose..."
        sudo apt install -y python3-pip
        pip3 install --user podman-compose
    fi

    print_info "Run 'source $profile' or restart your terminal to use 'docker' → podman"
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

print_header "Switching from Docker CE to Podman on Pop!_OS"

disable_docker
remove_docker_packages           # comment this line if you want to keep config files
install_podman
setup_drop_in_replacement

# Optional: install Podman Desktop (uncomment if you want the GUI)
install_podman_desktop

print_header "Done!"
echo -e "${GREEN}Podman is now ready to use as 'docker'${NC}"
echo "Run 'source ~/.bashrc' (or ~/.zshrc) to activate the alias immediately."
echo "Test with: docker --version   (should show podman)"
echo "           docker run hello-world"
