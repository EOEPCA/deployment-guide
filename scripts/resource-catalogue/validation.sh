

#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "default" "io.kompose.service=pycsw" 1
check_deployment_ready "default" "resource-catalogue-service"

check_service_exists "default" "resource-catalogue-db"
check_service_exists "default" "resource-catalogue-service"

check_url_status_code "https://resource-catalogue.$INGRESS_HOST" "200"
check_pvc_bound "default" "db-data-resource-catalogue-db-0"

check_configmap_exists "default" "resource-catalogue-db-configmap"
check_configmap_exists "default" "resource-catalogue-configmap"

echo
echo "All Resources:"
echo
kubectl get all -l io.kompose.service=pycsw --all-namespaces
