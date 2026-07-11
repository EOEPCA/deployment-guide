#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check pods in resource-registration namespace
check_pods_running "resource-registration" "" 6

# Check services
check_service_exists "resource-registration" "registration-api-service"
check_service_exists "resource-registration" "registration-harvester-bpm-engine-postgres-hl"
check_service_exists "resource-registration" "registration-harvester-bpm-engine-operaton"
check_service_exists "resource-registration" "registration-harvester-bpm-engine-postgres"
check_service_exists "resource-registration" "registration-harvester-worker-landsat-service"
check_service_exists "resource-registration" "registration-harvester-worker-sentinel-service"
check_service_exists "resource-registration" "registration-harvester-worker-stac-service"

# Check ingress
if [ "${INGRESS_CLASS:-}" == "apisix" ]; then
  kubectl -n resource-registration get apisixroute registration-api >/dev/null
  kubectl -n resource-registration get apisixroute registration-harvester-bpm-engine >/dev/null
else
  kubectl -n resource-registration get ingress registration-api >/dev/null
  kubectl -n resource-registration get ingress registration-harvester-bpm-engine >/dev/null
fi
#
# Registration API
if [ "${RESOURCE_REGISTRATION_ENABLE_OIDC:-no}" == "yes" ]; then
    CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://registration-api.$INGRESS_HOST" "302"
else
    check_url_status_code "$HTTP_SCHEME://registration-api.$INGRESS_HOST" "200"
fi
# Operaton BPM engine REST API (unauthenticated by default)
check_url_status_code "$HTTP_SCHEME://registration-harvester-bpm-engine.$INGRESS_HOST/engine-rest/engine" "200"

echo
echo "All Resources in 'resource-registration' namespace:"
echo
kubectl get all -n resource-registration
