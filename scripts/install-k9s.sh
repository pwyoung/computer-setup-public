#!/bin/bash

# 1. Configuration
INSTALL_DIR="/usr/local/bin"
TEMP_DIR=$(mktemp -d)

# 2. Detect Architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    K9S_ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    K9S_ARCH="arm64"
else
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
fi

echo "🔍 Detected Architecture: $K9S_ARCH"

# 3. Get the Latest Version Tag from GitHub
echo "🔍 Checking for the latest K9s version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo "❌ Failed to fetch latest version. Please check your internet connection."
    exit 1
fi

echo "✅ Found latest version: $LATEST_VERSION"

# 4. Construct Download URL
# File naming convention example: k9s_Linux_amd64.tar.gz
FILENAME="k9s_Linux_${K9S_ARCH}.tar.gz"
URL="https://github.com/derailed/k9s/releases/download/${LATEST_VERSION}/${FILENAME}"

# 5. Download and Install
echo "⬇️  Downloading $FILENAME..."
curl -L -o "$TEMP_DIR/$FILENAME" "$URL"

echo "📦 Extracting..."
tar -xzf "$TEMP_DIR/$FILENAME" -C "$TEMP_DIR" k9s

echo "🚀 Installing to $INSTALL_DIR (requires sudo)..."
sudo mv "$TEMP_DIR/k9s" "$INSTALL_DIR/k9s"
sudo chmod +x "$INSTALL_DIR/k9s"

# 6. Cleanup and Verify
rm -rf "$TEMP_DIR"

echo "---"
if command -v k9s >/dev/null; then
    echo "🎉 Success! k9s installed."
    k9s version | head -n 1
else
    echo "❌ Installation failed."
fi
