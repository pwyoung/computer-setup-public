#!/bin/bash

# Goal
# - Share SSH-AGENT with multiple terminals
#
# Steps
# - Call this from a login script (and when a terminal tab is created)

SSH_PRIVATE_KEY=~/.ssh/id_ed25519

# File to store the SSH agent environment variables
SSH_ENV="$HOME/.ssh/agent-environment"

# Log output from this script
LOG=~/.ssh-agent.sh.out

# Stay logged in this long
DURATION='2d'

add_key() {
    echo "Current keys" >>$LOG
    ssh-add -l >>$LOG

    # public key's unique value
    SSH_PUB_KEY="${SSH_PRIVATE_KEY}.pub"
    PKV=$(cat "${SSH_PUB_KEY}" | awk '{print $3 }')
    echo "Public key identifier: $PKV" >>$LOG
    if ssh-add -l | grep "$PKV" >>$LOG; then
        echo "Public key has been added already" >>$LOG
    else
        echo "Public key has NOT been added already" >>$LOG
        ssh-add -t $DURATION "${SSH_PRIVATE_KEY}"
    fi

    echo "Updated keys"
    ssh-add -l >>$LOG
}

# Our SSH agent process was not found.
start_agent() {
    echo "Starting new SSH agent..." >>$LOG

    # For simplicity/testing, kill any other ssh-agent processes
    if pgrep ssh-agent; then
        echo "First kill existing ssh-agent processes" >>$LOG
        pkill ssh-agent >>$LOG
    fi

    # Start the SSH agent and redirect output to the environment file
    ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    chmod 600 "${SSH_ENV}"

    ls -l "${SSH_ENV}" >>$LOG
    . "${SSH_ENV}" >>$LOG

}

ensure_agent_is_running() {
    echo "SSH_ENV is" >>$LOG
    ls -l "$SSH_ENV" >>$LOG
    echo "SSH_ENV contains" >>$LOG
    cat "$SSH_ENV" >>$LOG

    # Source SSH agent settings if the agent environment file exists
    if [ -f "${SSH_ENV}" ]; then
        . "${SSH_ENV}" >>$LOG

        # Check if the agent is still running using the stored PID
        ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent >>$LOG

        if [ $? -eq 0 ]; then
            echo "Using existing SSH agent" >>$LOG
        else
            # If agent is not running, start a new one
            start_agent
        fi
    else
        # If environment file doesn't exist, start a new agent
        start_agent
    fi

}

run() {
    echo "START: `date`" >$LOG
    ensure_agent_is_running
    add_key
    echo "END: `date`" >>$LOG
}

run

