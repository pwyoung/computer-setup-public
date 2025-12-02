#!/bin/bash


# 1. Download the official Helm installation script
echo "Downloading the official Helm installation script..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to download get_helm.sh. Aborting."
    exit 1
fi

# 2. Make the script executable
echo "Setting execute permissions on the script..."
chmod 700 get_helm.sh

# 3. Execute the script to install the latest Helm binary
# The script will attempt to install to /usr/local/bin by default (requires sudo/root)
# If you don't want to use sudo, you can modify the script or run it with: DESIRED_VERSION=vX.Y.Z ./get_helm.sh
echo "Running the installation script. This may require sudo if installing to a system path like /usr/local/bin."

# Using 'sudo' to ensure installation into a system-wide PATH location like /usr/local/bin
sudo ./get_helm.sh

# 4. Clean up the downloaded script
echo "Cleaning up..."
rm get_helm.sh

# 5. Verify the installation
echo "Verifying Helm installation..."
if command -v helm &> /dev/null; then
    echo "Helm installed successfully!"
    helm version --short
else
    echo "Helm installation failed. Please check the output above for errors."
    exit 1
fi



