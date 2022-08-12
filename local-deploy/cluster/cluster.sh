#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source functions
ACTION="${1:-apply}"
configureAction "$ACTION"
cluster_name="${2:-mykube}"

# minikube
./minikube.sh "${cluster_name}"

# deduce ip address from minikube
initIpDefaults
public_ip="${3:-${default_public_ip}}"
domain="${4:-${default_domain}}"

# metallb (Load Balancer)
if [ "${USE_METALLB}" = "true" ]; then
  ./metallb.sh "${ACTION}" "${public_ip}"
fi

# ingress-nginx
./ingress-nginx.sh "${ACTION}"

if [ "${USE_TLS}" = "true" ]; then
  # Certificate manager
  ./certificate-manager.sh "${ACTION}"
  # Cluster Issuer
  ./letsencrypt.sh "${ACTION}"
fi

# Sealed Secrets
./sealed-secrets.sh "${ACTION}" "${cluster_name}"

# Minio
if [ "${STAGEOUT_TARGET}" = "minio" ]; then
  ./minio.sh "${ACTION}" "${domain}"
else
  echo "SKIPPING minio deployment - not required for ADES stage-out"
fi
