#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

# Check if the Application Quality pod is running
check_pods_running "application-quality" "app.kubernetes.io/name=application-quality" 1

# Check service
check_service_exists "application-quality" "application-quality"

# Check ingress
check_url_status_code "$HTTP_SCHEME://application-quality.${INGRESS_HOST}" "200"

echo
echo "All Resources in 'application-quality' namespace:"
echo
kubectl get all -n application-quality