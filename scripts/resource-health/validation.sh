#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

check_service_exists "resource-health" "resource-health-web" || exit 1
check_service_exists "resource-health" "resource-health-check-api" || exit 1
check_service_exists "resource-health" "resource-health-telemetry-api" || exit 1
check_service_exists "resource-health" "resource-health-opentelemetry-collector" || exit 1
check_service_exists "resource-health" "opensearch-cluster-master" || exit 1
check_service_exists "resource-health" "resource-health-opensearch-dashboards" || exit 1

check_statefulset_ready "resource-health" "resource-health-opensearch" || exit 1
kubectl wait --for=condition=Available deployment --all \
  -n resource-health --timeout=300s || exit 1

if [ "$RESOURCE_HEALTH_ENABLE_OIDC" = "no" ]; then
  for path in /api/healthchecks/v1/check_templates/ /api/telemetry/v1/spans; do
    for attempt in {1..12}; do
      if check_url_status_code "${HTTP_SCHEME}://resource-health.${INGRESS_HOST}${path}" 200; then
        break
      fi
      [ "$attempt" -eq 12 ] && exit 1
      sleep 5
    done
  done
fi

echo
echo "All Resources in 'resource-health' namespace:"
echo
kubectl get all -n resource-health
