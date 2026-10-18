# ==============================================================================
# Zellij Dynamic Tab Naming (Supports Bash and Zsh)
# Source this from ~/.bashrc or ~/.zshrc
# ==============================================================================

set_zellij_tab_name() {
    if [[ -n "${ZELLIJ:-}" ]]; then
        #local current_dir="${PWD##*/}"
        local current_dir="${PWD/#$HOME/\~}"
        [[ -z "$current_dir" ]] && current_dir="/"
        zellij action rename-tab "$current_dir" >/dev/null 2>&1
    fi
}

# SSH wrapper to temporarily rename the tab to the remote host name
ssh() {
  if [[ -n "${ZELLIJ:-}" ]]; then
    local host rc
    host="$1"
    zellij action rename-tab "${host:-ssh}"
    command ssh "$@"; rc=$?
    zellij action undo-rename-tab
    return $rc
  fi
  command ssh "$@"
}

# Shell-specific hook setup
if [[ -n "${BASH_VERSION:-}" ]]; then
    # Bash prompt command integration
    PROMPT_COMMAND="set_zellij_tab_name${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    # Zsh chpwd hook integration
    autoload -U add-zsh-hook
    add-zsh-hook chpwd set_zellij_tab_name
    # Set the tab name immediately upon sourcing in the current directory
    set_zellij_tab_name
fi
