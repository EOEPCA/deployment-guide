#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source functions
initIpDefaults

ACTION="${1:-apply}"
cluster_name="${2:-mykube}"
public_ip="${3:-${default_public_ip}}"
domain="${4:-${default_domain}}"

# minikube
./minikube.sh "${cluster_name}"

# metallb (Load Balancer)
./metallb.sh "${ACTION}" "${public_ip}"

# ingress-nginx
./ingress-nginx.sh "${ACTION}"

# Certificate manager
./certificate-manager.sh "${ACTION}"

# Cluster Issuer
./letsencrypt.sh "${ACTION}"

# Sealed Secrets
./sealed-secrets.sh "${ACTION}" "${cluster_name}"

# Minio
./minio.sh "${ACTION}" "${domain}"
