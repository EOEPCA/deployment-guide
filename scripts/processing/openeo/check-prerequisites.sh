#!/bin/bash

source ../../common/utils.sh
source ../../common/prerequisite-utils.sh
echo "🔍 Checking prerequisites for OpenEO Deployment..."

declare -a checks=(
    "check_kubernetes_access"
    "check_kubectl_installed"
    "check_helm_installed"
    "check_git_installed"
    "check_cert_manager_installed"
    "check_ingress_controller_installed"
    "check_oidc_provider_accessible"
)

run_validation "${checks[@]}"