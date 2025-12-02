#!/bin/bash

set -e

get_approval() {
    read -p "Enter 'Y' to install Docker-CE. Or enter to skip" X
    if [ "$X" == "Y" ]; then
        echo "ok"
    else
        exit 0
    fi
}


docker_ce() {
    # 1. Check if Docker is already installed
    if command -v docker &> /dev/null; then
        echo "Docker is already installed"
        # Check permissions/group membership
        if ! docker run hello-world > /dev/null 2>&1; then
            echo "Docker is installed, but 'docker run' failed."
            echo "If you just installed Docker, you may need to log out and back in,"
            echo "or reboot to recognize the group membership."
            echo "Current user groups: $(groups)"
            sleep 3
            exit 1
        else
            echo "Docker is running correctly."
            return
        fi
    fi

    # 2. Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        LIKE=$ID_LIKE
    else
        echo "Cannot detect OS. /etc/os-release missing."
        exit 1
    fi

    echo "Detected OS: $OS (Like: $LIKE)"

    # 3. Installation Logic based on OS
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" || "$LIKE" =~ "ubuntu" || "$LIKE" =~ "debian" ]]; then
        echo "Installing Docker-CE for Debian/Ubuntu..."

        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg

        # Create keyring directory if it doesn't exist
        if [ ! -d /etc/apt/keyrings ]; then
            sudo install -m 0755 -d /etc/apt/keyrings
        fi

        # Add GPG Key if missing
        if [ ! -e /etc/apt/keyrings/docker.gpg ]; then
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
        fi

        # Add Repository
        if [ ! -e /etc/apt/sources.list.d/docker.list ]; then
            echo \
            "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        fi

        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    elif [[ "$OS" == "rhel" || "$OS" == "centos" || "$OS" == "fedora" || "$LIKE" =~ "rhel" || "$LIKE" =~ "fedora" || "$LIKE" =~ "centos" ]]; then
        echo "Installing Docker-CE for RHEL/CentOS/Fedora..."

        # RHEL/CentOS often have podman installed which conflicts
        echo "Removing conflicting packages (podman, buildah) if present..."
        sudo dnf remove -y podman buildah docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true

        # Install utils
        sudo dnf install -y dnf-plugins-core

        # Add Repo
        sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

        # Install Docker
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # RHEL derivatives do NOT start the service by default
        echo "Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker

    else
        echo "Unsupported OS family: $OS"
        exit 1
    fi

    # 4. Post-Install: Group Configuration
    if ! groups | grep -q docker; then
        echo "Adding $USER to docker group"
        sudo usermod -aG docker $USER

        # Newgrp allows us to use the new group without logging out in the current shell context
        # strictly for the test, but we still advise the user to relogin.
        echo "----------------------------------------------------"
        echo "Docker installed. You have been added to the 'docker' group."
        echo "Please LOG OUT and LOG BACK IN to apply group changes."
        echo "----------------------------------------------------"

        # We attempt to activate the group change for the current session to test
        newgrp docker <<EONG
        docker run hello-world
EONG
        exit 0
    fi

    # 5. Final Test
    docker run hello-world
}

get_approval
docker_ce
