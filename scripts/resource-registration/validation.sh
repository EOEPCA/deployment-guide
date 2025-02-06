#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check pods in resource-registration namespace
check_pods_running "resource-registration" "" 4

# Check services
check_service_exists "resource-registration" "registration-api-service"
check_service_exists "resource-registration" "registration-harvester-api-engine-postgres-hl"
check_service_exists "resource-registration" "registration-harvester-api-engine-flowable-rest"
check_service_exists "resource-registration" "registration-harvester-api-engine-postgres"
check_service_exists "resource-registration" "registration-harvester-worker-service"

# Check ingress
check_url_status_code "$HTTP_SCHEME://registration-api.$INGRESS_HOST" "200"
CHECK_USER=${FLOWABLE_ADMIN_USER} CHECK_PASSWORD=${FLOWABLE_ADMIN_PASSWORD} check_url_status_code "$HTTP_SCHEME://registration-harvester-api.$INGRESS_HOST/flowable-rest/service/repository/deployments" "200"

echo
echo "All Resources in 'resource-registration' namespace:"
echo
kubectl get all -n resource-registration
