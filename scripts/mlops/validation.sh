#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

# Check if GitLab, SharingHub, MLflow and its Postgres backend pods are running
check_pods_running "gitlab" "app=webservice" 1
check_pods_running "sharinghub" "app.kubernetes.io/name=sharinghub" 1
check_pods_running "sharinghub" "app.kubernetes.io/name=mlflow-sharinghub" 1
check_pods_running "sharinghub" "app=mlflow-postgres" 1

check_service_exists "gitlab" "gitlab-webservice-default"
check_service_exists "sharinghub" "sharinghub"
check_service_exists "sharinghub" "mlflow-sharinghub"
check_service_exists "sharinghub" "mlflow-postgres"

check_url_status_code "$HTTP_SCHEME://gitlab.$INGRESS_HOST/users/sign_in" "200"
check_url_status_code "$HTTP_SCHEME://sharinghub.$INGRESS_HOST" "200"
check_url_status_code "$HTTP_SCHEME://sharinghub.$INGRESS_HOST/api/stac/collections" "200"
check_url_status_code "$HTTP_SCHEME://sharinghub.$INGRESS_HOST/mlflow/" "401"

if ! check_s3_bucket_exists "$S3_BUCKET_SHARINGHUB"; then
    exit 1
fi
if ! check_s3_bucket_exists "$S3_BUCKET_MLFLOW"; then
    exit 1
fi

echo
echo "All Resources in 'gitlab' namespace:"
echo
kubectl get all -n gitlab

echo
echo "All Resources in 'sharinghub' namespace:"
echo
kubectl get all -n sharinghub