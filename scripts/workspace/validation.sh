#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check pods in workspace namespace
check_pods_running "workspace" "" 11

# Check services
check_service_exists "crossplane-system" "crossplane-webhooks"
check_service_exists "crossplane-system" "provider-helm"
check_service_exists "crossplane-system" "provider-keycloak"
check_service_exists "crossplane-system" "provider-kubernetes"
check_service_exists "crossplane-system" "provider-minio"
check_service_exists "crossplane-system" "crossplane-contrib-function-auto-ready"
check_service_exists "crossplane-system" "crossplane-contrib-function-environment-configs"
check_service_exists "crossplane-system" "crossplane-contrib-function-python"
check_service_exists "workspace" "workspace-admin-api"
check_service_exists "workspace" "workspace-admin-auth"
check_service_exists "workspace" "workspace-admin-kong-proxy"
check_service_exists "workspace" "workspace-admin-metrics-scraper"
check_service_exists "workspace" "workspace-admin-web"
check_service_exists "workspace" "workspace-api"

# Check ingress
CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/probe" "200"
CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/docs" "302"
CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://workspace-api.$INGRESS_HOST/" "302"

echo
echo "All Resources in 'workspace' namespace:"
echo
kubectl get all -n workspace
