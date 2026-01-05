#!/bin/bash
source ../../common/utils.sh
source ../../common/validation-utils.sh

if [ -z "$OIDC_OAPIP_ENABLED" ]; then
    ask "OIDC_OAPIP_ENABLED" "Do you want to enable authentication using the IAM Building Block?" "true" is_boolean
fi

check_pods_running "processing" "app.kubernetes.io/name=zoo-project-dru-kubeproxy" 1
check_pods_running "processing" "app=zoo-project-dru-postgresql" 1
check_pods_running "processing" "app.kubernetes.io/instance=zoo-project-dru" 2
check_pods_running "processing" "app.kubernetes.io/instance=zoo-project-dru-zoofpm" 1

check_deployment_ready "processing" "zoo-project-dru-kubeproxy"
check_deployment_ready "processing" "zoo-project-dru-zoofpm"
check_deployment_ready "processing" "zoo-project-dru-zookernel"

check_service_exists "processing" "zoo-project-dru-kubeproxy"
check_service_exists "processing" "zoo-project-dru-postgresql-service"
check_service_exists "processing" "zoo-project-dru-rabbitmq"
check_service_exists "processing" "zoo-project-dru-service"

if [ "$OIDC_OAPIP_ENABLED" == "true" ]; then
    CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://zoo.$INGRESS_HOST" "302"
    CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://zoo.$INGRESS_HOST/ogc-api/processes" "302"
else
    check_url_status_code "$HTTP_SCHEME://zoo.$INGRESS_HOST" "200"
    check_url_status_code "$HTTP_SCHEME://zoo.$INGRESS_HOST/ogc-api/processes" "200"
fi

CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://zoo.$INGRESS_HOST/swagger-ui/oapip/" "200"

echo
echo "All Resources:"
echo
kubectl get all -l app.kubernetes.io/name=zoo-project-dru-kubeproxy --all-namespaces
kubectl get all -l app.kubernetes.io/instance=zoo-project-dru --all-namespaces
