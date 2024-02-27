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
provided_domain="${3}"

# minikube
if [ "${REQUIRE_MINIKUBE}" = "true" ]; then
  ./minikube.sh "${cluster_name}"
fi

# deduce ip address from minikube
initIpDefaults
domain="${provided_domain:-${default_domain}}"
public_ip="${4:-${default_public_ip}}"

# metallb (Load Balancer)
if [ "${USE_METALLB}" = "true" ]; then
  ./metallb.sh "${ACTION}" "${public_ip}"
fi

# ingress-nginx
if [ "${REQUIRE_INGRESS_NGINX}" = "true" ]; then
  ./ingress-nginx.sh "${ACTION}" "${domain}" "${public_ip}"
fi

if [ "${USE_TLS}" = "true" ]; then
  # Certificate manager
  if [ "${REQUIRE_CERT_MANAGER}" = "true" ]; then
    ./certificate-manager.sh "${ACTION}"
  fi
  # Cluster Issuer
  if [ "${REQUIRE_LETSENCRYPT}" = "true" ]; then
    ./letsencrypt.sh "${ACTION}"
  fi
fi

# Sealed Secrets
if [ "${REQUIRE_SEALED_SECRETS}" = "true" ]; then
  ./sealed-secrets.sh "${ACTION}" "${cluster_name}"
fi

# Minio
if [ "${REQUIRE_MINIO}" = "true" ]; then
  ./minio.sh "${ACTION}" "${domain}"
fi
