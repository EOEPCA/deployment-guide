#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check services
check_service_exists "resource-health" "opensearch-cluster-master-headless"
check_service_exists "resource-health" "resource-health-web"
check_service_exists "resource-health" "opensearch-cluster-master"
check_service_exists "resource-health" "resource-health-opensearch-dashboards"
check_service_exists "resource-health" "resource-health-mockapi"
check_service_exists "resource-health" "resource-health-api"
check_service_exists "resource-health" "resource-health-opentelemetry-collector"

echo
echo "All Resources in 'resource-health' namespace:"
echo
kubectl get all -n resource-health