#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check pods in resource-health namespace
check_pods_running "resource-health" "" 1

# Check pods in resource-health-opensearch namespace
check_pods_running "resource-health-opensearch" "" 3

# Check services
check_service_exists "resource-health" "resource-health"
check_service_exists "resource-health-opensearch" "opensearch-cluster-master"
check_service_exists "resource-health-opensearch" "opensearch-dashboards"

# Check ingress
check_url_status_code "https://resource-health.$INGRESS_HOST" "200"
check_url_status_code "https://opensearch-dashboards.$INGRESS_HOST" "200"

echo
echo "All Resources in 'resource-health' namespace:"
echo
kubectl get all -n resource-health

echo
echo "All Resources in 'resource-health-opensearch' namespace:"
echo
kubectl get all -n resource-health-opensearch