#!/usr/bin/env bash

# GOAL
# - Override "cd"
# - Allow this to automatically activate virtual envs etc.

_check_and_activate_venv() {
    # Check if a .venv directory with an activate script exists right here
    if [[ -f ".venv/bin/activate" ]]; then
        # Use ${VIRTUAL_ENV:-} to prevent errors if the variable is unset
        if [[ "${VIRTUAL_ENV:-}" != "$PWD/.venv" ]]; then
            echo "Activating venv"
            source ".venv/bin/activate"
        fi

    # If there is no .venv here, check if we currently have an active environment
    elif [[ -n "${VIRTUAL_ENV:-}" ]]; then
        # Strip '/.venv' from the end of the active path to get the project root
        # (It is safe to use VIRTUAL_ENV here because the elif confirmed it is set)
        local venv_parent="${VIRTUAL_ENV%/.venv}"

        # If our current directory is NO LONGER inside that project root, deactivate
        if [[ "$PWD" != "$venv_parent"* ]]; then
            echo "🛑 Left project directory. Deactivating venv..."
            deactivate
        fi
    fi
}

cd() {
    # Call the actual system 'cd' command
    builtin cd "$@" || return "$?"

    # Run the custom function
    _check_and_activate_venv
}
