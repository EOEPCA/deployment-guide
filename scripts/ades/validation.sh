

#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "default" "app.kubernetes.io/name=zoo-project-dru-kubeproxy" 1
check_pods_running "default" "app.kubernetes.io/instance=zoo-project-dru" 3

check_deployment_ready "default" "zoo-project-dru-kubeproxy"
check_deployment_ready "default" "zoo-project-dru-zoofpm"
check_deployment_ready "default" "zoo-project-dru-zookernel"
check_deployment_ready "default" "zoo-project-dru-protection"

check_service_exists "default" "zoo-project-dru-rabbitmq-headless"
check_service_exists "default" "zoo-project-dru-postgresql-hl"
check_service_exists "default" "zoo-project-dru-service"
check_service_exists "default" "zoo-project-dru-postgresql"
check_service_exists "default" "zoo-project-dru-rabbitmq"

check_url_status_code "https://zoo.$INGRESS_HOST" "200"
check_url_status_code "https://zoo-open.$INGRESS_HOST" "200"

echo
echo "All Resources:"
echo
kubectl get all -l app.kubernetes.io/name=zoo-project-dru-kubeproxy --all-namespaces
kubectl get all -l app.kubernetes.io/instance=zoo-project-dru --all-namespaces
