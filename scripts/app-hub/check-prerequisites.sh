#!/bin/bash

source ../common/utils.sh
source ../common/prerequisite-utils.sh
echo "🔍 Checking prerequisites for App Hub deployment..."

declare -a checks=(
    "check_kubernetes_access"
    "check_kubectl_installed"
    "check_helm_installed"
    "check_cert_manager_installed"
    "check_apisix_ingress_installed"
    "check_oidc_provider_accessible"
)

run_validation "${checks[@]}"