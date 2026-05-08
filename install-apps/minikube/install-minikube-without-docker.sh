#!/bin/bash

# GOAL
# Install minikube natively (no Docker) with NodePort and LoadBalancer support.
#
# Linux  : 'none' driver  – Kubernetes runs as processes directly on this host.
#           NodePort services bind to real host interfaces (no tunnel needed).
#
# macOS  : 'qemu2' driver – Kubernetes runs in a native QEMU VM (no Docker).
#           socket_vmnet gives the host direct access to the VM network,
#           enabling NodePort and LoadBalancer via 'minikube tunnel'.

set -e

UPGRADE_KUBECTL="${UPGRADE_KUBECTL:-true}"
DELETE_EXISTING_CLUSTER="${DELETE_EXISTING_CLUSTER:-false}"

OS="$(uname -s)"
ARCH="$(uname -m)"
[ "$ARCH" = "x86_64" ] && ARCH_KUBE="amd64" || ARCH_KUBE="arm64"

echo "--- Detected: $OS ($ARCH) ---"

# ─── macOS ───────────────────────────────────────────────────────────────────
if [ "$OS" = "Darwin" ]; then

    if ! command -v brew &>/dev/null; then
        echo "Error: Homebrew is not installed. Please install it first."
        exit 1
    fi

    echo "--- Installing minikube, kubectl, QEMU, and socket_vmnet ---"
    brew install minikube kubectl qemu socket_vmnet

    # socket_vmnet must run as a privileged launch daemon so the QEMU VM
    # gets a routable IP on the host network (required for NodePort access).
    echo "--- Configuring socket_vmnet service (requires sudo) ---"
    BREW_BIN="$(which brew)"
    sudo "${BREW_BIN}" services start socket_vmnet 2>/dev/null || true

    echo "--- Starting minikube (qemu2 + socket_vmnet) ---"
    minikube start \
        --driver=qemu2 \
        --network=socket_vmnet

# ─── Linux / Ubuntu ──────────────────────────────────────────────────────────
elif [ "$OS" = "Linux" ]; then

    # Pin MINIKUBE_HOME to the invoking user's home so nested sudo calls
    # (which may reset $HOME to /root) all read/write the same profile dir.
    REAL_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
    export MINIKUBE_HOME="$REAL_HOME"

    echo "--- Installing prerequisites ---"
    # Recover from any interrupted dpkg transaction before touching apt
    sudo dpkg --configure -a
    # apt-get update may warn/fail on unrelated third-party repo GPG issues
    # (e.g. Microsoft keys); ignore those errors — conntrack/socat come from
    # the base Ubuntu repos which will still succeed.
    sudo apt-get update -q || true
    sudo apt-get install -y conntrack socat

    echo "--- Installing crictl ---"
    if ! command -v crictl &>/dev/null; then
        CRICTL_VERSION="$(curl -sL https://api.github.com/repos/kubernetes-sigs/cri-tools/releases/latest | grep tag_name | cut -d'"' -f4)"
        curl -sLO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH_KUBE}.tar.gz"
        sudo tar zxf "crictl-${CRICTL_VERSION}-linux-${ARCH_KUBE}.tar.gz" -C /usr/local/bin
        rm "crictl-${CRICTL_VERSION}-linux-${ARCH_KUBE}.tar.gz"
    fi

    echo "--- Installing kubectl ---"
    KUBE_VER="$(curl -sL https://dl.k8s.io/release/stable.txt)"
    if ! command -v kubectl &>/dev/null; then
        curl -sLO "https://dl.k8s.io/release/${KUBE_VER}/bin/linux/${ARCH_KUBE}/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    elif [ "$UPGRADE_KUBECTL" = "true" ]; then
        CURRENT_VER="$(kubectl version --client 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1)"
        if [ "$CURRENT_VER" != "$KUBE_VER" ]; then
            echo "    Upgrading kubectl $CURRENT_VER -> $KUBE_VER"
            curl -sLO "https://dl.k8s.io/release/${KUBE_VER}/bin/linux/${ARCH_KUBE}/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
        else
            echo "    kubectl already at $CURRENT_VER, skipping"
        fi
    fi

    echo "--- Installing minikube ---"
    if ! command -v minikube &>/dev/null; then
        curl -sLO "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${ARCH_KUBE}"
        sudo install "minikube-linux-${ARCH_KUBE}" /usr/local/bin/minikube
        rm "minikube-linux-${ARCH_KUBE}"
    fi

    echo "--- Enabling containerd CRI plugin ---"
    # Docker ships containerd with disabled_plugins=["cri"]. Kubernetes needs
    # the CRI endpoint, so we regenerate the config with CRI enabled and
    # SystemdCgroup=true (required for K8s cgroup management).
    if grep -q 'disabled_plugins.*cri' /etc/containerd/config.toml 2>/dev/null; then
        sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.bak
        containerd config default \
            | sed 's/SystemdCgroup = false/SystemdCgroup = true/' \
            | sudo tee /etc/containerd/config.toml > /dev/null
        sudo systemctl restart containerd
    fi

    echo "--- Starting minikube (none driver – runs directly on this host) ---"
    # 'none' driver: K8s components run as host processes; NodePort binds to
    # the real host NIC so services are reachable at localhost:<nodePort>.
    # Pass MINIKUBE_HOME explicitly — sudo strips exported env vars.
    MK="sudo MINIKUBE_HOME=$MINIKUBE_HOME minikube"
    CLUSTER_STATUS="$($MK status --format='{{.Host}}' 2>/dev/null || echo 'None')"
    if [ "$CLUSTER_STATUS" = "Running" ] && [ "$DELETE_EXISTING_CLUSTER" != "true" ]; then
        echo "    Cluster already running, skipping start"
    else
        if [ "$DELETE_EXISTING_CLUSTER" = "true" ]; then
            echo "    DELETE_EXISTING_CLUSTER=true — deleting cluster"
        fi
        $MK delete 2>/dev/null || true
        $MK start \
            --driver=none \
            --container-runtime=containerd
    fi

    # Ensure the invoking user owns ~/.minikube so non-sudo minikube commands work.
    # The none driver runs as root which leaves the directory root-owned.
    REAL_USER="$(stat -c '%U' "$REAL_HOME")"
    sudo chown -R "$REAL_USER:$REAL_USER" "$MINIKUBE_HOME"

    # Regenerate the kubeconfig entry so it points to the correct MINIKUBE_HOME.
    # Runs regardless of whether we started or skipped — fixes stale/missing context.
    $MK update-context
    # Copy minikube's kubeconfig to a dedicated file so it never clobbers the
    # user's main ~/.kube/config (which may point to other clusters).
    # Use: KUBECONFIG=~/.kube/minikube.config kubectl ...
    # Or add it to your KUBECONFIG env var alongside other configs.
    MINIKUBE_KUBECONFIG="$REAL_HOME/.kube/minikube.config"
    mkdir -p "$REAL_HOME/.kube"
    sudo cp /root/.kube/config "$MINIKUBE_KUBECONFIG" 2>/dev/null || true
    sudo chown "$(stat -c '%U:%G' "$REAL_HOME")" "$MINIKUBE_KUBECONFIG"
    sudo chmod 600 "$MINIKUBE_KUBECONFIG"
    echo "    Minikube kubeconfig: $MINIKUBE_KUBECONFIG"
    echo "    To use: KUBECONFIG=$MINIKUBE_KUBECONFIG kubectl get nodes"
    echo "    Or add to shell: export KUBECONFIG=\$KUBECONFIG:$MINIKUBE_KUBECONFIG"

else
    echo "Unsupported OS: $OS"
    exit 1
fi

echo ""
echo "--- Enabling addons ---"
minikube addons enable ingress
minikube addons enable metrics-server

echo ""
echo "--- Verification ---"
# minikube status may falsely report apiserver as Stopped on the none driver;
# confirm by querying the API directly instead.
minikube status || true
KUBECONFIG="${REAL_HOME:-$HOME}/.kube/minikube.config" kubectl get nodes

MINIKUBE_IP="$(minikube ip 2>/dev/null || echo '<minikube-ip>')"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Setup complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo " NodePort"
if [ "$OS" = "Linux" ]; then
    echo "   curl http://localhost:<nodePort>"
else
    echo "   minikube service <svc-name>"
    echo "   minikube service <svc-name> --url"
fi
echo ""
echo " LoadBalancer"
echo "   Run in a separate terminal: sudo minikube tunnel"
echo "   Then check the assigned IP:  kubectl get svc"
echo ""
echo " Ingress"
echo "   Add to /etc/hosts: ${MINIKUBE_IP}  <your-hostname>"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
