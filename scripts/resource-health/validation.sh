#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check critical services
check_service_exists "resource-health" "resource-health-web"
check_service_exists "resource-health" "resource-health-check-api"
check_service_exists "resource-health" "resource-health-telemetry-api"
check_service_exists "resource-health" "resource-health-opentelemetry-collector"
check_service_exists "resource-health" "opensearch-cluster-master"
check_service_exists "resource-health" "resource-health-opensearch-dashboards"

echo
echo "All Resources in 'resource-health' namespace:"
echo
kubectl get all -n resource-health
