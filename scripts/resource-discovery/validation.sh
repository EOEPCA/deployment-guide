#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "resource-discovery" "io.kompose.service=pycsw" 1
check_deployment_ready "resource-discovery" "resource-catalogue-service"

check_service_exists "resource-discovery" "resource-catalogue-db"
check_service_exists "resource-discovery" "resource-catalogue-service"

check_url_status_code "$HTTP_SCHEME://resource-catalogue.$INGRESS_HOST" "200"
check_url_status_code "$HTTP_SCHEME://resource-catalogue.$INGRESS_HOST/collections" "200"

check_pvc_bound "resource-discovery" "db-data-resource-catalogue-db-0"

check_configmap_exists "resource-discovery" "resource-catalogue-db-configmap"
check_configmap_exists "resource-discovery" "resource-catalogue-configmap"

echo
echo "All Resources:"
echo
kubectl get all -n resource-discovery
