#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check pods in data-access namespace
check_pods_running "data-access" "" 5

# Check services
check_service_exists "data-access" "eoapi-raster"
check_service_exists "data-access" "eoapi-stac"
check_service_exists "data-access" "eoapi-vector"
check_service_exists "data-access" "eoapi-doc-server"

check_service_exists "data-access" "eoapi-support-prometheus-server" "Skipping: eoapi-support not found." || true
check_service_exists "data-access" "eoapi-support-grafana" "Skipping: eoapi-support not found." || true

# Check ingress
check_url_status_code "$HTTP_SCHEME://eoapi.$INGRESS_HOST" "200"

echo
echo "All Resources in 'data-access' namespace:"
echo
kubectl get all -n data-access