

#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "default" "app.kubernetes.io/instance=identity-service" 4
check_deployment_ready "default" "identity-postgres"
check_deployment_ready "default" "identity-keycloak"
check_deployment_ready "default" "identity-api"

check_service_exists "default" "identity-postgres"
check_service_exists "default" "identity-keycloak"
check_service_exists "default" "identity-api"

check_url_status_code "$HTTP_SCHEME://identity.keycloak.$INGRESS_HOST" "200"
check_pvc_bound "default" "identity-service"

check_configmap_exists "default" "identity-keycloak"
check_configmap_exists "default" "identity-postgres-secret"

check_secret_exists "default" "identity-keycloak"
check_secret_exists "default" "identity-api"
check_secret_exists "default" "identity-postgres"

echo
echo "All Resources:"
echo
kubectl get all -l app.kubernetes.io/instance=identity-service --all-namespaces
