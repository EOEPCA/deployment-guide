#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "minio" "release=minio" 2

check_service_exists "minio" "minio-console"
check_service_exists "minio" "minio-svc"
check_service_exists "minio" "minio"

check_url_status_code "$HTTP_SCHEME://minio.$INGRESS_HOST" "403"
check_url_status_code "$HTTP_SCHEME://console-minio.$INGRESS_HOST" "200"

check_pvc_bound "minio" "export-minio-0"
check_pvc_bound "minio" "export-minio-1"

echo
echo "All Resources:"
echo
kubectl get all -l release=minio --all-namespaces
