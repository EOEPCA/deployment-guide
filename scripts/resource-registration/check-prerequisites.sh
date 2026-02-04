#!/bin/bash

source ../common/utils.sh
source ../common/prerequisite-utils.sh
echo "🔍 Checking prerequisites for Resource Registration deployment"

declare -a checks=(
    "check_kubernetes_access"
    "check_kubectl_installed"
    "check_helm_installed"
    "check_cert_manager_installed"
    "check_ingress_controller_installed"
    "check_rwx_storage"
)

if [[ "$RESOURCE_REGISTRATION_ENABLE_OIDC" == "yes" || "$RESOURCE_REGISTRATION_PROTECTED_TARGETS" == "yes" ]]; then
    checks+=("check_crossplane_installed")
fi

run_validation "${checks[@]}"