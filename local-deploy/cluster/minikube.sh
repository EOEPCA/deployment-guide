#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

CLUSTER_NAME="${1:-mykube}"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

#-------------------------------------------------------------------------------
# minikube
#-------------------------------------------------------------------------------
echo "Installing minikube..."
if ! hash minikube >/dev/null 2>&1; then
  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm -f ./minikube-linux-amd64
  echo "  [done]"
else
  echo "  [skip] already installed"
fi

minikube update-check

#-------------------------------------------------------------------------------
# create cluster
#-------------------------------------------------------------------------------
echo "Create minikube cluster..."
# minikube -p "${CLUSTER_NAME}" start --cpus max --memory max --kubernetes-version v1.21.5
minikube -p "${CLUSTER_NAME}" start --cpus max --memory 12g --kubernetes-version v1.21.5
minikube profile "${CLUSTER_NAME}"
echo "  [done]"
