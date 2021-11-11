#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

CLUSTER_NAME="${1:-mykube}"

minikube_ip="$(minikube ip)"
base_ip="$(echo -n $minikube_ip | cut -d. -f-3)"
default_public_ip="${base_ip}.123"
default_domain="${public_ip}.nip.io"

public_ip="${2:-${default_public_ip}}"
domain="${3:-${default_domain}}"

# minikube
./minikube.sh "${CLUSTER_NAME}"

# metallb (Load Balancer)
./metallb.sh "${public_ip}"

# ingress-nginx
./ingress-nginx.sh

# Certificate manager
./certificate-manager.sh

# Cluster Issuer
./letsencrypt.sh

# Sealed Secrets
./sealed-secrets.sh "${CLUSTER_NAME}"

# Minio
./minio.sh "${domain}"
