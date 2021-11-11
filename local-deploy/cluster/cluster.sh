#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

CLUSTER_NAME="${1:-mykube}"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

minikube_ip="$(minikube ip)"
base_ip="$(echo -n $minikube_ip | cut -d. -f-3)"
public_ip="${base_ip}.123"
domain="${public_ip}.nip.io"

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
