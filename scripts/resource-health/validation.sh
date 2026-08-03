#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

check_service_exists "resource-health" "resource-health-web"
check_service_exists "resource-health" "resource-health-check-api"
check_service_exists "resource-health" "resource-health-telemetry-api"
check_service_exists "resource-health" "resource-health-opentelemetry-collector"
check_service_exists "resource-health" "opensearch-cluster-master"
check_service_exists "resource-health" "resource-health-opensearch-dashboards"

# securityadmin.sh isn't automated by the chart (see bootstrap-opensearch-security.sh);
# catch the case where it was never run or needs re-running after a values change.
if kubectl exec -n resource-health resource-health-opensearch-0 -- \
  curl -sk https://localhost:9200/_cluster/health 2>/dev/null | grep -q "not initialized"; then
  echo "❌ OpenSearch security is not initialized. Run bootstrap-opensearch-security.sh."
else
  echo "✅ OpenSearch security is initialized."
fi

echo
echo "All Resources in 'resource-health' namespace:"
echo
kubectl get all -n resource-health
