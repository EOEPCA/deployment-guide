#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "default" "release=application-hub" 8

check_deployment_ready "default" "application-hub-proxy"
check_deployment_ready "default" "application-hub-user-scheduler"
check_deployment_ready "default" "application-hub-hub"

check_service_exists "default" "application-hub-proxy-public"
check_service_exists "default" "application-hub-proxy-api"
check_service_exists "default" "application-hub-hub"

check_url_status_code "https://app-hub.$INGRESS_HOST/hub/login" "200"

check_pvc_bound "default" "application-hub-hub-db-dir"

echo
echo "All Resources:"
echo
kubectl get all -l release=application-hub --all-namespaces
