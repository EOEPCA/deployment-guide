#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# if arg1 is "nomonitoring" then the eoAPI monitoring is not expected
NO_MONITORING="false"
if [ "$1" = "nomonitoring" ]; then
  NO_MONITORING="true"
fi

# if nomonitoring then expected pod count is 12 else 18
EXPECTED_POD_COUNT=18
if [ "$NO_MONITORING" = "true" ]; then
  EXPECTED_POD_COUNT=12
fi

# Check pods in data-access namespace
check_pods_running "data-access" "" ${EXPECTED_POD_COUNT}

# Check services
check_service_exists "data-access" "eoapi-raster"
check_service_exists "data-access" "eoapi-stac"
check_service_exists "data-access" "eoapi-vector"
check_service_exists "data-access" "eoapi-doc-server"

if [ "$NO_MONITORING" = "true" ]; then
  check_service_exists "data-access" "eoapi-support-prometheus-server" "Skipping: eoapi-support not found." || true
  check_service_exists "data-access" "eoapi-support-grafana" "Skipping: eoapi-support not found." || true
fi

# Check ingress
check_url_status_code "$HTTP_SCHEME://eoapi.$INGRESS_HOST" "200"

echo
echo "All Resources in 'data-access' namespace:"
echo
kubectl get all -n data-access