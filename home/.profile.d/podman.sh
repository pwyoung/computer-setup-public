#!/bin/bash

# If we don't have podman, exit this script
if ! command -v podman &>/dev/null; then
    exit 0
fi

# GOAL
# - Let 'docker compose' work on a podman system

# Notes
# - 'docker-compose' is legacy, deprecated in 2023. Don't use it.
# - 'podman-compose' is a community script, not official RedHat, but works well.
# - This approach uses the official 'docker-compose' helper with podman (the podman socket).

# Remove alias from (/usr/bin/) docker to podman
# sudo apt remove podman-docker
# which docker (nothing)

# Instal the official plugin (docker compose)
# sudo apt install docker-compose-plugin

# Enable the podman socket
# systemctl --user enable --now podman.socket



# Intercept "docker compose" and force it to use the official binary with the Podman socket
docker() {
    if [[ "$1" == "compose" ]]; then
        shift
        # Point DOCKER_HOST to Podman's socket just for this command
        DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock \
        /usr/libexec/docker/cli-plugins/docker-compose "$@"
    else
        # For all other commands, just run podman
        command podman "$@"
    fi
}
