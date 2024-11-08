#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_daemonset_ready "application-hub" "application-hub-continuous-image-puller"

check_deployment_ready "application-hub" "application-hub-proxy"
check_deployment_ready "application-hub" "application-hub-user-scheduler"
check_deployment_ready "application-hub" "application-hub-hub"

check_service_exists "application-hub" "application-hub-proxy-public"
check_service_exists "application-hub" "application-hub-proxy-api"
check_service_exists "application-hub" "application-hub-hub"

check_url_status_code "$HTTP_SCHEME://app-hub.$INGRESS_HOST/hub/login" "200"

check_pvc_bound "application-hub" "application-hub-hub-db-dir"

echo
echo "All Resources:"
echo
kubectl get all -l release=application-hub --all-namespaces
