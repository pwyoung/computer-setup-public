#!/bin/bash

# GOAL
# - Update NVM and NPM regularly

# NOTES
# - Use a flag file to remember the time (hour) of the last update
#   and update if the file is absent or the time exceeds INTERVAL_HOURS
# - This is tested on Ubuntu but should work on EL-based Linux too.


# --- Configuration ---
INTERVAL_HOURS=168
FLAG_FILE="$HOME/.npm-update.flag"
TIMESTAMP_FORMAT="%Y%m%d%H"
NVM_DIR="$HOME/.nvm"

# --- OS Detection & Dependency Setup ---

install_system_deps() {
    echo ">>> Checking system dependencies..."
    if [ -f /etc/debian_version ]; then
        echo "Detected Debian/Ubuntu-based system."
        sudo apt update && sudo apt install -y curl grep sed
    elif [ -f /etc/redhat-release ]; then
        echo "Detected RHEL-based system."
        # Using dnf (standard in RHEL 8+) with a fallback to yum
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y curl grep sed
        else
            sudo yum install -y curl grep sed
        fi
    else
        echo "Unsupported OS. Please install curl, grep, and sed manually."
    fi
}

# --- NVM Logic ---

load_nvm() {
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

should_update() {
    # 1. Absence Check (Fresh Install)
    if [ ! -d "$NVM_DIR" ]; then
        return 0
    fi

    # 2. Flag Check
    if [ ! -f "$FLAG_FILE" ]; then
        return 0
    fi

    # 3. Time Check
    local last_update_unix
    last_update_unix=$(stat -c %Y "$FLAG_FILE")
    local current_unix=$(date +%s)
    local diff_hours=$(( (current_unix - last_update_unix) / 3600 ))

    [ "$diff_hours" -ge "$INTERVAL_HOURS" ]
}

perform_upgrade() {
    install_system_deps

    echo ">>> Fetching latest NVM release..."
    local latest_nvm
    latest_nvm=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm}/install.sh" | bash
    load_nvm

    echo ">>> Installing/Upgrading Node.js..."
    nvm install node --reinstall-packages-from=node
    nvm alias default node

    npm install -g npm@latest

    # Tool List with String Appends
    local TOOL_LIST=()
    TOOL_LIST+=("@openai/codex")
    TOOL_LIST+=("rank")
    TOOL_LIST+=("react")
    TOOL_LIST+=("dotenv-cli")

    echo ">>> Updating global tools..."
    for tool in "${TOOL_LIST[@]}"; do
        npm install -g "$tool" --quiet
    done

    # Record timestamp
    date +"$TIMESTAMP_FORMAT" > "$FLAG_FILE"
    echo ">>> Finish Time: $(date)"
}

# --- Main ---
if should_update; then
    perform_upgrade
else
    echo ">>> System is within the update interval. No action taken."
fi
