#!/bin/bash

source ../common/utils.sh
source ../common/prerequisite-utils.sh
echo "🔍 Checking prerequisites for IAM deployment..."

check_iam_ingress_supported() {
    if [ "${INGRESS_CLASS}" = "apisix" ]; then
        echo "✅ IAM ingress mode is supported: apisix."
        return 0
    fi

    echo "❌ IAM requires INGRESS_CLASS=apisix for this guide."
    echo "   nginx cannot render the APISIX OIDC route plugins used by IAM."
    return 1
}

check_keycloak_provider_crds_installed() {
    local missing=0
    for crd in \
        providerconfigs.keycloak.m.crossplane.io \
        clients.openidclient.keycloak.m.crossplane.io; do
        if kubectl get crd "$crd" >/dev/null 2>&1; then
            echo "✅ CRD '$crd' exists."
        else
            echo "❌ CRD '$crd' is missing."
            missing=1
        fi
    done

    if [ "$missing" -ne 0 ]; then
        echo "   Install the Crossplane Keycloak provider before deploying IAM."
        return 1
    fi
}

declare -a checks=(
    "check_kubernetes_access"
    "check_kubectl_installed"
    "check_helm_installed"
    "check_cert_manager_installed"
    "check_iam_ingress_supported"
    "check_apisix_ingress_installed"
    "check_crossplane_installed"
    "check_keycloak_provider_crds_installed"
)

run_validation "${checks[@]}"
