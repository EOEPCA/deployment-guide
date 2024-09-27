

#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "default" "app.kubernetes.io/instance=workspace-api" 1
check_deployment_ready "default" "workspace-api"

check_service_exists "default" "workspace-api"

check_url_status_code "https://workspace-api.$INGRESS_HOST" "200"

echo
echo "All Resources:"
echo
kubectl get all -l app=harbor --all-namespaces
