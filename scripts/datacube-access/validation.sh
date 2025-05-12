#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "datacube-access" "app.kubernetes.io/name=datacube-access" 1
check_deployment_ready "datacube-access" "datacube-access"

check_service_exists "datacube-access" "datacube-access"

check_url_status_code "https://datacube-access.$INGRESS_HOST/" "200"
check_url_status_code "https://datacube-access.$INGRESS_HOST/conformance" "200"
check_url_status_code "https://datacube-access.$INGRESS_HOST/collections" "200"

echo
echo "All Resources:"
kubectl get all -n datacube-access