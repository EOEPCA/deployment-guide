#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

# Minikube options
export USE_MINIKUBE_NONE_DRIVER="${USE_MINIKUBE_NONE_DRIVER:-true}"
export MINIKUBE_KUBERNETES_VERSION="${MINIKUBE_KUBERNETES_VERSION:-v1.22.5}"
export MINIKUBE_MEMORY_AMOUNT="${MINIKUBE_MEMORY_AMOUNT:-12g}"

# Ingress options
export USE_METALLB="${USE_METALLB:-false}"
export USE_INGRESS_NGINX_HELM="${USE_INGRESS_NGINX_HELM:-false}"
export USE_INGRESS_NGINX_LOADBALANCER="${USE_INGRESS_NGINX_LOADBALANCER:-false}"

# TLS options
export USE_TLS="${USE_TLS:-true}"
export TLS_CLUSTER_ISSUER="${TLS_CLUSTER_ISSUER:-letsencrypt-staging}"
if [ "${USE_TLS}" = "false" ]; then export TLS_CLUSTER_ISSUER="notls"; fi

# Default Credentials
export LOGIN_SERVICE_ADMIN_PASSWORD="${LOGIN_SERVICE_ADMIN_PASSWORD:-changeme}"
export MINIO_ROOT_USER="${MINIO_ROOT_USER:-eoepca}"
export MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-changeme}"
export HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD:-changeme}"

# Data
export CREODIAS_DATA_SPECIFICATION="${CREODIAS_DATA_SPECIFICATION:-false}"

# OpenStack details for Bucket Operator
#
# EOEPCA operations user with administrative privileges
export OS_DOMAINNAME="${OS_DOMAINNAME:-cloud_XXXXX}"
export OS_USERNAME="${OS_USERNAME:-user@cloud.com}"  # e.g. email address
export OS_PASSWORD="${OS_PASSWORD:-none}"
#
# ID of a specific role (e.g. the '_member_' role) for operations users (to allow administration)
export OS_MEMBERROLEID="${OS_MEMBERROLEID:-none}"
#
# ID of a project containing the user identity requiring write access to the created user buckets
export OS_SERVICEPROJECTID="${OS_SERVICEPROJECTID:-none}"
export USER_EMAIL_PATTERN="${USER_EMAIL_PATTERN:-eoepca+<name>@platform.com}"

source ../cluster/functions
ACTION="${1:-apply}"
configureAction "$ACTION"
cluster_name="${2:-eoepca}"

# Create the cluster
../cluster/cluster.sh "${ACTION}" "${cluster_name}" $3 $4

# deduce ip address from minikube
initIpDefaults
public_ip="${3:-${default_public_ip}}"
domain="${4:-${default_domain}}"

# storage
echo -e "\nstorage..."
./storage.sh "${ACTION}"

# dummy-service
echo -e "\nDeploy dummy-service..."
./dummy-service.sh "${ACTION}" "${domain}"

# login-service
echo -e "\nDeploy login-service..."
./login-service.sh "${ACTION}" "${public_ip}" "${domain}"

# pdp
echo -e "\nDeploy pdp..."
./pdp.sh "${ACTION}" "${public_ip}" "${domain}"

# user-profile
echo -e "\nDeploy user-profile..."
./user-profile.sh "${ACTION}" "${public_ip}" "${domain}"

# ades
echo -e "\nDeploy ades..."
./ades.sh "${ACTION}" "${domain}"

# resource catalogue
echo -e "\nDeploy resource-catalogue..."
./resource-catalogue.sh "${ACTION}" "${domain}"

# data access
echo -e "\nDeploy data-access..."
./data-access.sh "${ACTION}" "${domain}"

# workspace api
echo -e "\nDeploy workspace-api..."
./workspace-api.sh "${ACTION}" "${public_ip}" "${domain}"

# bucket operator
echo -e "\nDeploy bucket-operator..."
./bucket-operator.sh "${ACTION}" "${domain}"

# harbor artefact registry
echo -e "\nDeploy harbor..."
./harbor.sh "${ACTION}" "${domain}"
