#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail


# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
    echo "[-] This script must be run as root (use sudo)."
    exit 1
fi

echo "[*] Checking for OpenTofu installation..."

# Check if tofu is already available and functioning
if command -v tofu &> /dev/null; then
    CURRENT_VERSION=$(tofu --version | head -n 1)
    echo "[+] OpenTofu is already installed ($CURRENT_VERSION)."
    echo "[*] Ensuring the official repository and latest patches are up to date..."
else
    echo "[*] OpenTofu is not found. Proceeding with installation..."
fi

# Step 1: Install prerequisites idempotently
echo "[*] Ensuring required dependencies are installed..."
apt-get update -qq
apt-get install -y -qq apt-transport-https ca-certificates curl gnupg > /dev/null

# Step 2: Set up OpenTofu GPG keys securely
echo "[*] Configuring OpenTofu GPG keyring..."
install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/opentofu.gpg ]; then
    curl -fsSL https://get.opentofu.org/opentofu.gpg | tee /etc/apt/keyrings/opentofu.gpg > /dev/null
    chmod a+r /etc/apt/keyrings/opentofu.gpg
fi

if [ ! -f /etc/apt/keyrings/opentofu-repo.gpg ]; then
    curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | gpg --no-tty --batch --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg > /dev/null
    chmod a+r /etc/apt/keyrings/opentofu-repo.gpg
fi

# Step 3: Add OpenTofu repository idempotently
REPO_FILE="/etc/apt/sources.list.d/opentofu.list"
REPO_LINE="deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main"

if [ ! -f "$REPO_FILE" ] || ! grep -qxF "$REPO_LINE" "$REPO_FILE"; then
    echo "[*] Adding OpenTofu repository to system sources..."
    echo "$REPO_LINE" > "$REPO_FILE"
else
    echo "[*] OpenTofu repository is already configured."
fi

# Step 4: Install or update OpenTofu via apt
echo "[*] Updating package index and installing/upgrading OpenTofu..."
apt-get update -qq
apt-get install -y -qq tofu > /dev/null

# Final verification
if command -v tofu &> /dev/null; then
    INSTALLED_VERSION=$(tofu --version | head -n 1)
    echo "[SUCCESS] OpenTofu is successfully installed and ready: $INSTALLED_VERSION"
else
    echo "[-] Installation failed. Please check for errors above."
    exit 1
fi


# Ensure script is run with sudo or as root
if [[ $EUID -ne 0 ]]; then
    echo "[-] This script must be run as root (use sudo)."
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    TG_ARCH="amd64"
    TFLINT_ARCH="amd64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    TG_ARCH="arm64"
    TFLINT_ARCH="arm64"
else
    echo "[-] Unsupported architecture: $ARCH"
    exit 1
fi

# Ensure required commands are present
for cmd in curl wget unzip jq awk grep; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "[+] Installing missing dependency: $cmd"
        apt-get update && apt-get install -y "$cmd"
    fi
done

# --- 1. Install / Update Terragrunt ---
echo "[*] Checking Terragrunt..."
TG_LATEST=$(curl -s "https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest" | jq -r .tag_name)
if [[ -z "$TG_LATEST" || "$TG_LATEST" == "null" ]]; then
    echo "[-] Failed to fetch latest Terragrunt version from GitHub API."
    exit 1
fi

TG_CURRENT=""
if command -v terragrunt &> /dev/null; then
    # Extract version string (e.g., v0.65.0 -> strip extra output if any)
    TG_CURRENT="v$(terragrunt --version | awk '{print $3}' | sed 's/^v//')"
fi

if [[ "$TG_CURRENT" != "$TG_LATEST" ]]; then
    echo "[+] Updating/Installing Terragrunt from $TG_CURRENT to $TG_LATEST..."
    TG_URL="https://github.com/gruntwork-io/terragrunt/releases/download/${TG_LATEST}/terragrunt_linux_${TG_ARCH}"

    TMP_TG=$(mktemp)
    wget -q "$TG_URL" -O "$TMP_TG"
    chmod +x "$TMP_TG"
    mv "$TMP_TG" /usr/local/bin/terragrunt
    echo "[✔] Terragrunt successfully updated to $TG_LATEST"
else
    echo "[✔] Terragrunt is already up-to-date ($TG_CURRENT)"
fi

# --- 2. Install / Update TFLint ---
echo "[*] Checking TFLint..."
TFLINT_LATEST=$(curl -s "https://api.github.com/repos/terraform-linters/tflint/releases/latest" | jq -r .tag_name)
if [[ -z "$TFLINT_LATEST" || "$TFLINT_LATEST" == "null" ]]; then
    echo "[-] Failed to fetch latest TFLint version from GitHub API."
    exit 1
fi

TFLINT_CURRENT=""
if command -v tflint &> /dev/null; then
    TFLINT_CURRENT="v$(tflint --version | head -n 1 | awk '{print $3}' | sed 's/^v//')"
fi

if [[ "$TFLINT_CURRENT" != "$TFLINT_LATEST" ]]; then
    echo "[+] Updating/Installing TFLint from $TFLINT_CURRENT to $TFLINT_LATEST..."
    TFLINT_URL="https://github.com/terraform-linters/tflint/releases/download/${TFLINT_LATEST}/tflint_linux_${TFLINT_ARCH}.zip"

    TMP_ZIP=$(mktemp)
    TMP_DIR=$(mktemp -d)

    wget -q "$TFLINT_URL" -O "$TMP_ZIP"
    unzip -q "$TMP_ZIP" -d "$TMP_DIR"
    chmod +x "$TMP_DIR/tflint"
    mv "$TMP_DIR/tflint" /usr/local/bin/tflint

    rm -rf "$TMP_ZIP" "$TMP_DIR"
    echo "[✔] TFLint successfully updated to $TFLINT_LATEST"
else
    echo "[✔] TFLint is already up-to-date ($TFLINT_CURRENT)"
fi

echo "[✔] All infrastructure tooling checks complete!"


tofu version
terragrunt --version
tflint --version
