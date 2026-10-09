#!/bin/bash

source ../common/utils.sh
source ../common/prerequisite-utils.sh
echo "🔍 Checking prerequisites for Trivy Operator (security scanner) deployment..."

declare -a checks=(
    "check_kubernetes_access"
    "check_kubectl_installed"
    "check_helm_installed"
)

run_validation "${checks[@]}"
