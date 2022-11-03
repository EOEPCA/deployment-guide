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
# minikube profile
#-------------------------------------------------------------------------------
if [ "${USE_MINIKUBE_NONE_DRIVER}" = "false" ]; then
  minikube_profile="${cluster_name}"
else
  minikube_profile="minikube"
fi

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

#-------------------------------------------------------------------------------
# create cluster
#-------------------------------------------------------------------------------
echo "Create minikube cluster..."
if minikube -p "${minikube_profile}" ip >/dev/null 2>&1; then
  echo "  [skip] already running"
else
  if [ "${USE_MINIKUBE_NONE_DRIVER}" = "false" ]; then
    minikube -p "${minikube_profile}" start --cpus max --memory "${MINIKUBE_MEMORY_AMOUNT}" --kubernetes-version "${MINIKUBE_KUBERNETES_VERSION}"
    minikube profile "${minikube_profile}"
  else
    minikube start --driver none --kubernetes-version "${MINIKUBE_KUBERNETES_VERSION}"
  fi
  echo "  [done]"
fi
