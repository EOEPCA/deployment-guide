#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

# Check if the Application Quality pod is running
check_pods_running "application-quality" "app.kubernetes.io/component=api" 1
check_pods_running "application-quality" "app=application-quality-db" 1
check_pods_running "application-quality" "app.kubernetes.io/component=web" 1

# Check service
check_service_exists "application-quality" "application-quality-api"
check_service_exists "application-quality" "application-quality-db"
check_service_exists "application-quality" "application-quality-web"

# Check ingress
check_url_status_code "$HTTP_SCHEME://application-quality.${INGRESS_HOST}" "200"

echo
echo "All Resources in 'application-quality' namespace:"
echo
kubectl get all -n application-quality