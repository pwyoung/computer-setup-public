#!/bin/bash

# --- Helper Functions ---

# Fetches the latest version tag of NVM from the GitHub API
get_latest_nvm_version() {
    local version
    version=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "${version:-v0.40.4}" # Fallback to a known stable version if API call fails
}

# Loads NVM into the current shell session so the script can use 'nvm' and 'npm'
load_nvm() {
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
        \. "$NVM_DIR/bash_completion"
    else
        echo "Error: NVM not found after installation attempt."
        exit 1
    fi
}

# --- Core Tasks ---

install_nvm_and_node() {
    local LATEST_NVM
    LATEST_NVM=$(get_latest_nvm_version)

    echo ">>> Latest NVM version detected: $LATEST_NVM"
    echo ">>> Downloading and installing NVM..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM}/install.sh" | bash

    load_nvm

    echo ">>> Installing latest Node.js and updating NPM..."
    nvm install node
    nvm alias default node
    npm install -g npm@latest
}

install_global_tools() {
    local TOOL_LIST=()

    # Append AI/Codex Tools
    TOOL_LIST+=("@openai/codex")

    # Append Ranking/Data Tools
    TOOL_LIST+=("rank")

    # Append React/Web Tools
    TOOL_LIST+=("create-react-app")
    TOOL_LIST+=("react")

    # Append Environment/Utility Tools
    TOOL_LIST+=("dotenv-cli")
    TOOL_LIST+=("dotenv")

    echo ">>> Installing ${#TOOL_LIST[@]} tools globally via NPM..."

    for tool in "${TOOL_LIST[@]}"; do
        echo "Processing: $tool"
        npm install -g "$tool" --quiet
    done
}

# --- Main Logic ---

main() {
    # System dependencies
    sudo apt update && sudo apt install -y curl grep sed

    # Run the installation stack
    install_nvm_and_node
    install_global_tools

    echo "--------------------------------------------------"
    echo "Installation Finished Successfully!"
    echo "NVM:  $(nvm --version)"
    echo "Node: $(node -v)"
    echo "NPM:  $(npm -v)"
    echo "--------------------------------------------------"
    echo "IMPORTANT: Restart your terminal or run: source ~/.bashrc"
}

main
