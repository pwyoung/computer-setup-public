#!/bin/bash

if ! command -v kubectl; then
    mkdir -p ~/bin-local
    cd ~/bin-local
    if [ ! -e ./kubectl ]; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    fi
    chmod 0700 ~/bin-local/kubectl
fi


#kubectl version
kubectl version --client
