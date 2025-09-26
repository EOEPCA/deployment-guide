#!/bin/bash

source ../../common/utils.sh
source ../../common/prerequisite-utils.sh
echo "🔍 Checking prerequisites for Processing deployment..."

declare -a checks=(
    "check_kubernetes_access"
    "check_kubectl_installed"
    "check_helm_installed"
    "check_cert_manager_installed"
    "check_ingress_controller_installed"
    "check_rwx_storage"

    # Processing prerequisite check goes on the assumption that stage in and stage out object stores are the same.
    "check_object_store_accessible"
)

run_validation "${checks[@]}"