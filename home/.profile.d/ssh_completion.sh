# GOAL
# - Provide SSH completion in BASH and ZSH shells
# - Support aliases defined in ~/.ssh/config
# - Support aliases defined in dirs included from ~/.ssh/config

# Shared helper function to extract hostnames from config and known_hosts
__get_ssh_hosts() {
    local config_file="$HOME/.ssh/config"
    local known_hosts_file="$HOME/.ssh/known_hosts"
    local -a config_files=()

    # 1. Parse known_hosts
    # Splits on comma to handle [host]:port format, ignores hashed hosts (|) or bracketed IPs
    if [[ -f "$known_hosts_file" ]]; then
        awk '{split($1,a,","); if (a[1] !~ /^\[/ && a[1] !~ /^\|/) print a[1]}' "$known_hosts_file"
    fi

    # 2. Parse config files (handling Includes)
    if [[ -f "$config_file" ]]; then
        config_files+=("$config_file")

        # Extract 'Include' paths and expand globs
        # We loop through the main config to find Include directives
        while read -r _ include_path; do
            # Handle tilde expansion if present
            include_path="${include_path/#\~/$HOME}"

            # Handle relative paths (prepend ~/.ssh/ if path doesn't start with /)
            if [[ "$include_path" != /* ]]; then
                include_path="$HOME/.ssh/$include_path"
            fi

            # Expand globs (e.g., ~/.ssh/config.d/*) and add valid files to array
            for f in $include_path; do
                [[ -f "$f" ]] && config_files+=("$f")
            done
        done < <(grep -i "^Include " "$config_file")

        # Parse all collected files for Host directives
        # Iterates through all fields ($2 to $NF) to catch multiple aliases
        # Excludes patterns containing wildcards (* or ?)
        awk '/^Host / {
            for (i=2; i<=NF; i++) {
                if ($i !~ /[*?]/) print $i
            }
        }' "${config_files[@]}" 2>/dev/null
    fi
}

# ZSH Completion Function
_ZSH_complete_ssh_hosts() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    # Generate list, sort unique, and match against current input
    local ssh_hosts
    ssh_hosts=$(__get_ssh_hosts | sort -u)

    COMPREPLY=( $(compgen -W "${ssh_hosts}" -- "$cur") )
    return 0
}

# Bash Completion Function
_complete_ssh_hosts() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    local ssh_hosts
    ssh_hosts=$(__get_ssh_hosts | sort -u)

    COMPREPLY=( $(compgen -W "${ssh_hosts}" -- "$cur") )
    return 0
}

# Bind the functions
# Check if running in Zsh or Bash to apply correctly
if [[ -n "$ZSH_VERSION" ]]; then
    # Zsh (assuming bashcompinit is enabled as per your snippet style)
    autoload -U +X bashcompinit && bashcompinit
    complete -F _ZSH_complete_ssh_hosts ssh
elif [[ -n "$BASH_VERSION" ]]; then
    # Bash
    complete -F _complete_ssh_hosts ssh
fi
