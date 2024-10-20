#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check pods in data-access namespace
check_pods_running "data-access" "" 5

# Check services
check_service_exists "data-access" "eoapi"
check_service_exists "data-access" "stacture"
check_service_exists "data-access" "tyk-gateway"

# Check ingress
check_url_status_code "$HTTP_SCHEME://eoapi.$INGRESS_HOST" "200"
check_url_status_code "$HTTP_SCHEME://stacture.$INGRESS_HOST" "200"

echo
echo "All Resources in 'data-access' namespace:"
echo
kubectl get all -n data-access