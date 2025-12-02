#!/bin/bash

set -e

docker_ce() {
    if docker --version; then
        echo "Docker is already installed"
        if ! docker run hello-world; then
            echo "If you just installed docker, then reboot"
            echo "to make sure all processes know you're in the docker group"
            sleep 3
            exit 1
        fi
        return
    fi

    echo "Install Docker-CE"
    echo "Per https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository"

    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg

    if [ ! -e /etc/apt/keyrings/docker.gpg ]; then
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
    fi

    if [ ! -e /etc/apt/sources.list.d/docker.list ]; then
        echo \
            "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    if ! groups | grep docker; then
        echo "Adding $USER to docker group"
        sudo usermod -aG docker $USER
        echo "Exiting: Log in again"
        exit 1
    fi

    # Test it
    docker run hello-world
}

docker_ce
