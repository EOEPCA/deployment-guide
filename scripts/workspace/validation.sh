#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# if arg1 is "noadmin" then the Admin Dashboard is not expected
NO_ADMIN_DEPLOYMENT="false"
if [ "$1" = "noadmin" ]; then
  NO_ADMIN_DEPLOYMENT="true"
fi

# if noadmin then expected pod count is 6 else 11
EXPECTED_POD_COUNT=11
if [ "$NO_ADMIN_DEPLOYMENT" = "true" ]; then
  EXPECTED_POD_COUNT=6
fi

# Check pods in workspace namespace
check_pods_running "workspace" "" $EXPECTED_POD_COUNT

# Check services
check_service_exists "crossplane-system" "crossplane-webhooks"
check_service_exists "crossplane-system" "provider-helm"
check_service_exists "crossplane-system" "provider-keycloak"
check_service_exists "crossplane-system" "provider-kubernetes"
check_service_exists "crossplane-system" "provider-minio"
check_service_exists "crossplane-system" "crossplane-contrib-function-auto-ready"
check_service_exists "crossplane-system" "crossplane-contrib-function-environment-configs"
check_service_exists "crossplane-system" "crossplane-contrib-function-python"
check_service_exists "workspace" "workspace-api"
if [ "$NO_ADMIN_DEPLOYMENT" = "false" ]; then
  check_service_exists "workspace" "workspace-admin-api"
  check_service_exists "workspace" "workspace-admin-auth"
  check_service_exists "workspace" "workspace-admin-kong-proxy"
  check_service_exists "workspace" "workspace-admin-metrics-scraper"
  check_service_exists "workspace" "workspace-admin-web"
fi

# Check ingress
CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/probe" "200"
CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/docs" "302"
CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/" "302"

echo
echo "All Resources in 'workspace' namespace:"
echo
kubectl get all -n workspace
