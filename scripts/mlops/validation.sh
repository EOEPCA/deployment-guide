#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

# Check if the SharingHub and MLflow pods are running
check_pods_running "sharinghub" "app.kubernetes.io/name=sharinghub" 1
check_pods_running "sharinghub" "app.kubernetes.io/name=mlflow-sharinghub" 1

# Check services
check_service_exists "sharinghub" "sharinghub"
check_service_exists "sharinghub" "mlflow-sharinghub"

# Check ingress
check_url_status_code "$HTTP_SCHEME://sharinghub.$INGRESS_HOST" "200"
check_url_status_code "$HTTP_SCHEME://sharinghub.$INGRESS_HOST/api/stac/collections" "200"
check_url_status_code "$HTTP_SCHEME://sharinghub.$INGRESS_HOST/mlflow/" "401"

echo
echo "All Resources in 'sharinghub' namespace:"
echo
kubectl get all -n sharinghub