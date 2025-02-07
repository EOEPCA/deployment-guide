

#!/bin/bash
source ../../common/utils.sh
source ../../common/validation-utils.sh

check_pods_running "processing" "app.kubernetes.io/name=zoo-project-dru-kubeproxy" 1
check_pods_running "processing" "app.kubernetes.io/instance=zoo-project-dru" 3

check_deployment_ready "processing" "zoo-project-dru-kubeproxy"
check_deployment_ready "processing" "zoo-project-dru-zoofpm"
check_deployment_ready "processing" "zoo-project-dru-zookernel"

check_service_exists "processing" "zoo-project-dru-rabbitmq-headless"
check_service_exists "processing" "zoo-project-dru-postgresql-hl"
check_service_exists "processing" "zoo-project-dru-service"
check_service_exists "processing" "zoo-project-dru-postgresql"
check_service_exists "processing" "zoo-project-dru-rabbitmq"

check_url_status_code "$HTTP_SCHEME://zoo.$INGRESS_HOST" "401"
check_url_status_code "$HTTP_SCHEME://zoo.$INGRESS_HOST/ogc-api/processes" "401"
check_url_status_code "$HTTP_SCHEME://zoo.$INGRESS_HOST/swagger-ui/oapip/" "200"

echo
echo "All Resources:"
echo
kubectl get all -l app.kubernetes.io/name=zoo-project-dru-kubeproxy --all-namespaces
kubectl get all -l app.kubernetes.io/instance=zoo-project-dru --all-namespaces
