#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "$HOME/.eoepca/state"

# Check pods in rm namespace
check_pods_running "rm" "" 3

# Check pods in registration-harvester-api namespace
check_pods_running "registration-harvester-api" "" 3

# Check services
check_service_exists "rm" "registration-api"
check_service_exists "registration-harvester-api" "registration-harvester-api-engine"

# Check ingress
check_url_status_code "http://registration-api.$INGRESS_HOST" "200"
check_url_status_code "http://registration-harvester-api.$INGRESS_HOST/flowable-ui/" "200"

echo
echo "All Resources in 'rm' namespace:"
echo
kubectl get all -n rm

echo
echo "All Resources in 'registration-harvester-api' namespace:"
echo
kubectl get all -n registration-harvester-api