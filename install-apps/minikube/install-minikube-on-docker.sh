#!/bin/bash

# GOAL
# - Install minikube, running on existing docker system

# Exit immediately if a command exits with a non-zero status
set -e

echo "--- Checking Prerequisites ---"

# Check if docker is running (checking for the docker socket)
if ! docker info &> /dev/null; then
    echo "Error: Docker does not seem to be running."
    exit 1
fi

echo "--- Installing Minikube and Kubernetes CLI ---"

if uname -a | grep Darwin; then
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew is not installed. Please install it first."
        exit 1
    fi
    # Install Minikube and kubectl via Homebrew
    brew install minikube kubectl
fi

echo "--- Configuring Minikube ---"

# Set the default driver to docker
minikube config set driver docker

echo "--- Starting Minikube ---"

# Start minikube
# We specify the driver explicitly just to be safe for the first run
minikube start --driver=docker

echo "--- Verification ---"

# Check the status
minikube status

echo "--- Setup Complete ---"
echo "You can now use 'kubectl get nodes' to see your cluster."
