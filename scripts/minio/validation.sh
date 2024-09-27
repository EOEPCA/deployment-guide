#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "default" "release=minio" 2

check_service_exists "default" "minio-console"
check_service_exists "default" "minio-svc"
check_service_exists "default" "minio"

check_url_status_code "https://minio.$INGRESS_HOST" "403"
check_url_status_code "https://console.minio.$INGRESS_HOST" "200"

check_pvc_bound "default" "export-minio-0"
check_pvc_bound "default" "export-minio-1"

echo
echo "All Resources:"
echo
kubectl get all -l release=minio --all-namespaces
