#!/bin/bash

# GOAL
# Remove minikube and its exclusive dependencies so either install script
# can run cleanly afterward. kubectl and other tools are left untouched.
#
# Steps:
#   1. Stop and delete the running minikube cluster (all drivers).
#   2. Remove the minikube binary from /usr/local/bin (Linux) or via
#      Homebrew (macOS).
#   3. On macOS: stop and uninstall socket_vmnet (installed solely for the
#      qemu2 minikube driver). qemu itself is left in place as it is
#      general-purpose.
#   4. On Linux: restore the containerd config.toml from the backup that
#      install-minikube-without-docker.sh created before modifying it.
#   5. Remove ~/.minikube (minikube cluster state, config, and cache).
#   6. Remove ~/.kube/minikube.config (the dedicated kubeconfig written by
#      install-minikube-without-docker.sh; the main ~/.kube/config is
#      not touched).

set -e

OS="$(uname -s)"

echo "--- Detected: $OS ---"

# ─── Stop and delete the cluster ─────────────────────────────────────────────
echo "--- Stopping and deleting minikube cluster ---"
if command -v minikube &>/dev/null; then
    if [ "$OS" = "Linux" ]; then
        # The 'none' driver runs minikube as root.
        REAL_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
        export MINIKUBE_HOME="$REAL_HOME"
        sudo MINIKUBE_HOME="$MINIKUBE_HOME" minikube stop  2>/dev/null || true
        sudo MINIKUBE_HOME="$MINIKUBE_HOME" minikube delete 2>/dev/null || true
    else
        minikube stop  2>/dev/null || true
        minikube delete 2>/dev/null || true
    fi
else
    echo "    minikube not found in PATH, skipping cluster teardown"
fi

# ─── macOS ────────────────────────────────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then

    if command -v brew &>/dev/null; then
        echo "--- Uninstalling minikube via Homebrew ---"
        brew uninstall --ignore-dependencies minikube 2>/dev/null || true

        # socket_vmnet is installed exclusively for minikube's qemu2 driver.
        if brew list socket_vmnet &>/dev/null 2>&1; then
            echo "--- Stopping and removing socket_vmnet ---"
            BREW_BIN="$(which brew)"
            sudo "${BREW_BIN}" services stop socket_vmnet 2>/dev/null || true
            brew uninstall --ignore-dependencies socket_vmnet 2>/dev/null || true
        fi
    else
        echo "    Homebrew not found — removing minikube binary manually if present"
        sudo rm -f /usr/local/bin/minikube
    fi

# ─── Linux ────────────────────────────────────────────────────────────────────
elif [ "$OS" = "Linux" ]; then

    echo "--- Removing minikube binary ---"
    sudo rm -f /usr/local/bin/minikube

    # Restore containerd config if install-minikube-without-docker.sh saved a backup.
    if [ -f /etc/containerd/config.toml.bak ]; then
        echo "--- Restoring original containerd config from backup ---"
        sudo cp /etc/containerd/config.toml.bak /etc/containerd/config.toml
        sudo rm -f /etc/containerd/config.toml.bak
        sudo systemctl restart containerd
    fi

else
    echo "Unsupported OS: $OS"
    exit 1
fi

# ─── Remove minikube data and config (both platforms) ────────────────────────
REAL_HOME="${REAL_HOME:-$HOME}"

echo "--- Removing ~/.minikube ---"
sudo rm -rf "$REAL_HOME/.minikube"

echo "--- Removing ~/.kube/minikube.config ---"
rm -f "$REAL_HOME/.kube/minikube.config"

echo ""
echo "--- Uninstall complete ---"
echo "kubectl and other tools are unchanged."
echo "You can now re-run either install script."
