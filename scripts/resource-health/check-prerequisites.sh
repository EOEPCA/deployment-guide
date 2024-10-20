#!/bin/bash

source ../common/utils.sh
source ../common/prerequisite-utils.sh
echo "🔍 Checking prerequisites for Resource Health deployment..."

declare -a checks=(
    "check_kubernetes_access"
    "check_kubectl_installed"
    "check_helm_installed"
    "check_cert_manager_installed"
    "check_ingress_controller_installed"
    "check_internal_certificates"
)

run_validation "${checks[@]}"