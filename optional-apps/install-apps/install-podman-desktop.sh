#!/usr/bin/env bash

GREP='grep --color'

TEST_DIR=~/test-docker

PACKAGES="podman podman-docker slirp4netns uidmap fuse-overlayfs podman-compose"
# podman: The core container engine.
# podman-docker: Creates a symbolic link so that the docker command points to podman, allowing you to use existing scripts or muscle memory.
# slirp4netns: Required for rootless networking, allowing you to run containers without needing sudo privileges.
# uidmap: Required for mapping user IDs in rootless containers.
# fuse-overlayfs: Provides the filesystem overlay driver, which is highly recommended for rootless storage performance.
# podman-compose: docker-compose support

MSG() {
  echo "### $1"
}

install_it() {
    if command -v podman &>/dev/null; then
        echo "podman is already installed"
    else
        sudo apt update && sudo apt install -y $PACKAGES
    fi

    $MSG 'Ensure rootless containers function correctly'
    echo "$USER:100000:65536" | sudo tee /etc/subuid &>/dev/null
    echo "$USER:100000:65536" | sudo tee /etc/subgid &>/dev/null

    MSG 'Confirm rootless setting for containers'
    $GREP "$USER" /etc/subuid
    $GREP "$USER" /etc/subgid

    echo '' | sudo tee /etc/containers/nodocker &>/dev/null
}

test_podman() {

    MSG 'Test version'
    podman --version

    MSG 'docker alias'
    docker run --rm hello-world | $GREP -i hello

    MSG 'Show rootless flag'
    podman info --format '{{.Host.Security.Rootless}}' | $GREP 'true'

    MSG 'Test the User Namespace (maps uid and gid to root)'
    podman unshare id | $GREP 'uid=0' | $GREP 'gid=0'

    mkdir -p $TEST_DIR
}

test_compose() {
    F1=$TEST_DIR/index.html
    cat <<EOF >$F1
<!DOCTYPE html>
<html>
<body>
    <h1>It works!</h1>
    <p>Docker Compose is running successfully.</p>
</body>
</html>
EOF

    F2=$TEST_DIR/docker-compose.yaml
    cat <<EOF >$F2
services:
  web-server:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html:ro
EOF

    cd $TEST_DIR
    docker compose up -d
    sleep 0.2
    curl http://localhost:8080 | $GREP success
}

install_it
test_podman
test_compose
