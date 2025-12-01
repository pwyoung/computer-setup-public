#!/bin/bash

# On Mac, set up Docker
# - If we have ARM/Apple-Silicon, cater to that.
# - If we have podman, cater to that.


# pwy commented on 20250714 when kafka broker was failing with java errors
#if uname -a | grep ARM64 &> /dev/null; then
#    export DOCKER_DEFAULT_PLATFORM=linux/amd64
#fi


if command -v podman-compose &>/dev/null; then
    export CONTAINERS_COMPOSE_PROVIDER=podman

    #   Executing external compose provider "/opt/homebrew/bin/podman-compose". Please see podman-compose(1) for how to disable this message. <<<<
    export PODMAN_COMPOSE_WARNING_LOGS=false
fi


