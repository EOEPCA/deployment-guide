#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

EXPECTED_POD_COUNT=6

check_pods_running "workspace" "" $EXPECTED_POD_COUNT

check_service_exists "crossplane-system" "crossplane-webhooks"
check_service_exists "crossplane-system" "provider-helm"
check_service_exists "crossplane-system" "provider-keycloak"
check_service_exists "crossplane-system" "provider-kubernetes"
check_service_exists "crossplane-system" "provider-minio"
check_service_exists "crossplane-system" "crossplane-contrib-function-auto-ready"
check_service_exists "crossplane-system" "crossplane-contrib-function-environment-configs"
check_service_exists "crossplane-system" "crossplane-contrib-function-python"
check_service_exists "workspace" "workspace-api"
check_clusterpolicy_exists "workspace-registry-ingress-class"

CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/probe" "200"
if [ "$OIDC_WORKSPACE_ENABLED" == "true" ]; then
    CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/docs" "200"
    CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/" "302"

    check_clusterpolicy_exists "workspace-session-iam"
else
    # No redirect plugin, but the Workspace API itself still requires a
    # Bearer token audienced for WORKSPACE_API_CLIENT_ID for anything beyond /docs
    CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/docs" "200"
fi

echo
echo "All Resources in 'workspace' namespace:"
echo
kubectl get all -n workspace
