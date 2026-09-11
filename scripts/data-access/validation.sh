#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# if arg1 is "nomonitoring" then the eoAPI monitoring is not expected
NO_MONITORING="false"
if [ "${1:-}" = "nomonitoring" ]; then
  NO_MONITORING="true"
fi

set -e

for deployment in eoapi-stac eoapi-raster eoapi-vector eoapi-multidim eoapi-browser eoapi-doc-server stac-manager titiler-openeo; do
  check_deployment_ready "data-access" "$deployment"
  check_service_exists "data-access" "$deployment"
done

if [ "${USE_EXTERNAL_POSTGRES:-no}" != "yes" ]; then
  check_deployment_ready "data-access" "pgo"
  # 'kubectl rollout status' only works for statefulsets with a RollingUpdate strategy
  for sts in $(
      kubectl get sts -n data-access \
        -l postgres-operator.crunchydata.com/cluster=eoapi \
        -o json |
        jq -r '.items[] |
          select((.spec.updateStrategy.type // "RollingUpdate") == "RollingUpdate") |
          .metadata.name'
    ); do
    kubectl rollout status statefulset -n data-access "$sts" --timeout=120s
  done
fi

if [ "${DATA_ACCESS_ENABLE_IAM:-no}" = "yes" ]; then
  check_deployment_ready "data-access" "eoapi-stac-auth-proxy"
fi

if [ "$NO_MONITORING" = "false" ]; then
  check_service_exists "data-access" "eoapi-support-prometheus-server"
  check_service_exists "data-access" "eoapi-support-grafana"
fi

if [ "${ENABLE_GEOPARQUET_EXPORT:-no}" = "yes" ]; then
  check_cronjob_exists "data-access" "geoparquet-exporter-complete"
  check_cronjob_exists "data-access" "geoparquet-exporter-incremental"
fi

check_url_status_code "$HTTP_SCHEME://eoapi.$INGRESS_HOST" "200"

echo
echo "All Resources in 'data-access' namespace:"
echo
kubectl get all -n data-access
