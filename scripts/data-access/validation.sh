#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# if arg1 is "nomonitoring" then the eoAPI monitoring is not expected
NO_MONITORING="false"
if [ "$1" = "nomonitoring" ]; then
  NO_MONITORING="true"
fi

# if nomonitoring then expected pod count is 13 else 18 (+1 if IAM is enabled, for stac-auth-proxy)
EXPECTED_POD_COUNT=18
if [ "$NO_MONITORING" = "true" ]; then
  EXPECTED_POD_COUNT=13
fi
if [ "${USE_EXTERNAL_POSTGRES:-no}" = "yes" ]; then
  EXPECTED_POD_COUNT=$((EXPECTED_POD_COUNT - 4))
fi
if [ "${DATA_ACCESS_ENABLE_IAM:-no}" = "yes" ]; then
  EXPECTED_POD_COUNT=$((EXPECTED_POD_COUNT + 1))
fi

check_pods_running "data-access" "" ${EXPECTED_POD_COUNT}

check_service_exists "data-access" "eoapi-raster"
check_service_exists "data-access" "eoapi-stac"
check_service_exists "data-access" "eoapi-vector"
check_service_exists "data-access" "eoapi-doc-server"
check_service_exists "data-access" "titiler-openeo"

if [ "$NO_MONITORING" = "false" ]; then
  check_service_exists "data-access" "eoapi-support-prometheus-server" "Skipping: eoapi-support not found." || true
  check_service_exists "data-access" "eoapi-support-grafana" "Skipping: eoapi-support not found." || true
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