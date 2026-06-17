#!/bin/bash

source ../common/utils.sh
source ../common/prerequisite-utils.sh
source ../common/validation-utils.sh
echo "🔍 Checking prerequisites for App Hub deployment..."

function check_keycloak_provider_crds_installed() {
    local missing=0

    for crd in \
        providerconfigs.keycloak.m.crossplane.io \
        clients.openidclient.keycloak.m.crossplane.io \
        users.user.keycloak.m.crossplane.io; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            echo "✅ CRD '$crd' exists."
        else
            echo "❌ CRD '$crd' is missing."
            missing=1
        fi
    done

    if [ "$missing" -ne 0 ]; then
        echo "   Install the IAM BB first so the Keycloak Crossplane provider CRDs are available."
        return 1
    fi

    return 0
}

declare -a checks=(
    "check_kubernetes_access"
    "check_kubectl_installed"
    "check_helm_installed"
    "check_cert_manager_installed"
    "check_ingress_controller_installed"
    "check_oidc_provider_accessible"
    "check_crossplane_installed"
    "check_keycloak_provider_crds_installed"
    "check_keycloak_provider_config_exists"
)

run_validation "${checks[@]}"
