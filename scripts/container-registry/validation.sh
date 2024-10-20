

#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "default" "app=harbor" 6

check_deployment_ready "default" "harbor-registry"
check_deployment_ready "default" "harbor-core"
check_deployment_ready "default" "harbor-jobservice"
check_deployment_ready "default" "harbor-portal"

check_service_exists "default" "harbor-core"
check_service_exists "default" "harbor-jobservice"
check_service_exists "default" "harbor-portal"
check_service_exists "default" "harbor-registry"
check_service_exists "default" "harbor-database"
check_service_exists "default" "harbor-redis"

check_url_status_code "$HTTP_SCHEME://harbor.$INGRESS_HOST" "200"
check_pvc_bound "default" "data-harbor-redis-0"

check_secret_exists "default" "harbor-core"
check_secret_exists "default" "harbor-database"
check_secret_exists "default" "harbor-jobservice"
check_secret_exists "default" "harbor-registry"
check_secret_exists "default" "harbor-registry-htpasswd"
check_secret_exists "default" "harbor"

echo
echo "All Resources:"
echo
kubectl get all -l app=harbor --all-namespaces
