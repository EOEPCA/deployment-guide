

#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "harbor" "app=harbor" 6

check_deployment_ready "harbor" "harbor-registry"
check_deployment_ready "harbor" "harbor-core"
check_deployment_ready "harbor" "harbor-jobservice"
check_deployment_ready "harbor" "harbor-portal"

check_service_exists "harbor" "harbor-core"
check_service_exists "harbor" "harbor-jobservice"
check_service_exists "harbor" "harbor-portal"
check_service_exists "harbor" "harbor-registry"
check_service_exists "harbor" "harbor-database"
check_service_exists "harbor" "harbor-redis"

check_url_status_code "$HTTP_SCHEME://harbor.$INGRESS_HOST" "200"
check_pvc_bound "harbor" "data-harbor-redis-0"

check_secret_exists "harbor" "harbor-core"
check_secret_exists "harbor" "harbor-database"
check_secret_exists "harbor" "harbor-jobservice"
check_secret_exists "harbor" "harbor-registry"
check_secret_exists "harbor" "harbor-registry-htpasswd"

echo
echo "All Resources:"
echo
kubectl get all -l app=harbor --all-namespaces
