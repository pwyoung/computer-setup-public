# GOAL
# - Provide SSH completion in BASH and ZSH shells
# - Support aliases defined in ~/.ssh/config
# - Support aliases defined in dirs included from ~/.ssh/config

# Shared helper logic
__get_ssh_hosts() {
    local config_file="$HOME/.ssh/config"
    local known_hosts_file="$HOME/.ssh/known_hosts"
    local -a config_files=()

    # 1. Parse known_hosts
    if [[ -f "$known_hosts_file" ]]; then
        awk '{split($1,a,","); if (a[1] !~ /^\[/ && a[1] !~ /^\|/) print a[1]}' "$known_hosts_file"
    fi

    # 2. Parse config files (handling Includes)
    if [[ -f "$config_file" ]]; then
        config_files+=("$config_file")
        while read -r _ include_path; do
            include_path="${include_path/#\~/$HOME}"
            if [[ "$include_path" != /* ]]; then
                include_path="$HOME/.ssh/$include_path"
            fi
            for f in $include_path; do
                [[ -f "$f" ]] && config_files+=("$f")
            done
        done < <(grep -i "^Include " "$config_file")

        awk '/^Host / {
            for (i=2; i<=NF; i++) {
                if ($i !~ /[*?]/) print $i
            }
        }' "${config_files[@]}" 2>/dev/null
    fi
}

# ------------------------------------------------------------------------------
# ZSH / macOS Logic
# ------------------------------------------------------------------------------
if [[ -n "$ZSH_VERSION" ]] || [[ "$(uname)" == "Darwin" ]]; then

    _ZSH_complete_ssh_hosts() {
        # 1. Prevent Zsh from falling back to filenames/users if we find nothing
        compopt +o default +o bashdefault 2>/dev/null

        local cur="${COMP_WORDS[COMP_CWORD]}"

        # 2. Generate list, filter underscores, sort
        local ssh_hosts=$(__get_ssh_hosts | grep -v "^_" | sort -u)

        COMPREPLY=( $(compgen -W "${ssh_hosts}" -- "$cur") )
        return 0
    }

    # Setup for Zsh
    autoload -U +X bashcompinit && bashcompinit

    # Remove any existing binding to ensure ours takes precedence
    complete -r ssh 2>/dev/null

    # Bind the function
    complete -F _ZSH_complete_ssh_hosts ssh

# ------------------------------------------------------------------------------
# Bash Logic
# ------------------------------------------------------------------------------
elif [[ -n "$BASH_VERSION" ]]; then

    _complete_ssh_hosts() {
        compopt +o default 2>/dev/null

        local cur="${COMP_WORDS[COMP_CWORD]}"
        local ssh_hosts=$(__get_ssh_hosts | sort -u)

        COMPREPLY=( $(compgen -W "${ssh_hosts}" -- "$cur") )
        return 0
    }

    # Setup for Bash
    complete -r ssh 2>/dev/null
    complete -F _complete_ssh_hosts ssh

fi
