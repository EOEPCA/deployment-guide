#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

cluster_name="${1:-mykube}"

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
if [ "${USE_MINIKUBE_NONE_DRIVER}" = "false" ]; then
  minikube -p "${cluster_name}" start --cpus max --memory "${MINIKUBE_MEMORY_AMOUNT}" --kubernetes-version "${MINIKUBE_KUBERNETES_VERSION}"
  minikube profile "${cluster_name}"
else
  minikube start --driver none --kubernetes-version "${MINIKUBE_KUBERNETES_VERSION}"
fi
echo "  [done]"
