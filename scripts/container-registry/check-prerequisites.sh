#!/bin/bash

source ../common/utils.sh
source ../common/prerequisite-utils.sh
echo "🔍 Checking prerequisites for Container Registry deployment..."

declare -a checks=(
    "check_kubernetes_access"
    "check_kubectl_installed"
    "check_helm_installed"
    "check_cert_manager_installed"
    "check_ingress_controller_installed"
)

run_validation "${checks[@]}"