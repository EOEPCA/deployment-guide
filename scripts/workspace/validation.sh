#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check pods in workspace namespace
check_pods_running "workspace" "" 5

# Check services
check_service_exists "workspace" "workspace-api-v2"
check_service_exists "workspace" "workspace-ui"
check_service_exists "workspace" "workspace-admin"

# Check ingress
check_url_status_code "https://workspace-api-v2.$INGRESS_HOST" "200"
check_url_status_code "https://workspace-ui.$INGRESS_HOST" "200"
check_url_status_code "https://workspace-admin.$INGRESS_HOST" "200"

echo
echo "All Resources in 'workspace' namespace:"
echo
kubectl get all -n workspace