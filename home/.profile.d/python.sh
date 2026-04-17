#!/usr/bin/env bash
set -euo pipefail

export INSIDE_EMACS=false

LOCAL_BIN="$HOME/.local/bin"
OS="$(uname -s)"
# Fallback to bash if SHELL is unset
CURRENT_SHELL="$(basename "${SHELL:-/bin/bash}")"

report() {
    echo "$@"
    #echo "$@" | tee ~/.profile-setup-python.sh.out
}

report "⚙️  Detecting shell environment..."

# Determine the correct profile file based on OS and Shell
if [[ "$CURRENT_SHELL" == "zsh" ]]; then
    PROFILE_FILE="$HOME/.zshrc"
elif [[ "$CURRENT_SHELL" == "bash" ]]; then
    if [[ "$OS" == "Darwin" ]]; then
        # macOS Terminal/iTerm opens login shells by default for bash
        PROFILE_FILE="$HOME/.bash_profile"
    else
        # Linux standard interactive shell
        PROFILE_FILE="$HOME/.bashrc"
    fi
else
    # Fallback for sh, dash, etc.
    PROFILE_FILE="$HOME/.profile"
    report "⚠️  Unrecognized shell ($CURRENT_SHELL). Defaulting to $PROFILE_FILE."
fi

report "✅ Shell detected: $CURRENT_SHELL. Target profile: $PROFILE_FILE"

# Check if the path is already configured in the target file
# Using grep to check the file directly rather than checking the active $PATH
if ! grep -q "export PATH=\"$LOCAL_BIN:\$PATH\"" "$PROFILE_FILE" 2>/dev/null; then
    report "🔧 Adding $LOCAL_BIN to PATH in $PROFILE_FILE..."

    # Ensure the file exists before appending
    touch "$PROFILE_FILE"

    report -e "\n# uv-managed python default\nexport PATH=\"$LOCAL_BIN:\$PATH\"" >> "$PROFILE_FILE"

    report "✅ Path appended to $PROFILE_FILE."
    report "⚠️  Important: Run 'source $PROFILE_FILE' or completely restart your terminal to apply the changes."
else
    report "✅ $LOCAL_BIN is already configured in $PROFILE_FILE."
fi

# Verify the current active session
if [[ ":$PATH:" == *":$LOCAL_BIN:"* ]]; then
    CURRENT_PY="$(command -v python || true)"
    if [[ "$CURRENT_PY" == "$LOCAL_BIN/python" ]]; then
        report "🔍 Session Verified: 'python' is currently pointing to -> $CURRENT_PY"
    else
        report "⚠️  Warning: $LOCAL_BIN is in your PATH, but 'python' resolves to $CURRENT_PY."
    fi
else
    report "💡 Note: The new PATH is not active in this session yet. Please reload your shell."
fi

# VENV
#VENV=~/.venv/bin/activate
#if [ -e $VENV ]; then
#    echo "Sourcing venv $VENV" | tee /tmp/x
#    #source $VENV
#    . $VENV
#else
#    echo "No venv $VENV" | tee /tmp/x
#fi

