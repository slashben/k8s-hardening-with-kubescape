#!/bin/bash

# Check if miniube is installed
if [ -x "$(command -v minikube)" ]; then
    echo "minikube is already installed"
else
    echo "minikube is not installed"
    echo "Installing minikube"
    # Install minikube
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
        && chmod +x minikube \
        && sudo mv minikube /usr/local/bin/
    # Check if successful
    if [ -x "$(command -v minikube)" ]; then
        echo "minikube is installed"
    else
        echo "minikube couldn't be installed"
        exit 1
    fi
fi

# Check if kubectl is installed
if [ -x "$(command -v kubectl)" ]; then
    echo "kubectl is already installed"
else
    echo "kubectl is not installed"
    echo "Installing kubectl"
    # Install kubectl
    curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/v1.8.0/bin/linux/amd64/kubectl \
        && chmod +x kubectl \
        && sudo mv kubectl /usr/local/bin/
    # Check if successful
    if [ -x "$(command -v kubectl)" ]; then
        echo "kubectl is installed"
    else
        echo "kubectl couldn't be installed"
        exit 1
    fi
fi

# Start minikube
echo "Starting minikube"
minikube start --mount=true


