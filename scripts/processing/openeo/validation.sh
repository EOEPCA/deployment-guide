#!/bin/bash
source ../../common/utils.sh
source ../../common/validation-utils.sh


check_pods_running "openeo-geotrellis" "app.kubernetes.io/instance=openeo-geotrellis-sparkoperator" 2
check_pods_running "openeo-geotrellis" "app.kubernetes.io/instance=openeo-geotrellis-zookeeper" 1
check_pods_running "openeo-geotrellis" "release=openeo-geotrellis-openeo" 2


check_deployment_ready "openeo-geotrellis" "openeo-geotrellis-sparkoperator-spark-operator-controller"
check_deployment_ready "openeo-geotrellis" "openeo-geotrellis-sparkoperator-spark-operator-webhook"

check_service_exists "openeo-geotrellis" "openeo-geotrellis-sparkoperator-spark-operator-webhook-svc"
check_service_exists "openeo-geotrellis" "openeo-geotrellis-zookeeper"
check_service_exists "openeo-geotrellis" "openeo-geotrellis-zookeeper-headless"
check_service_exists "openeo-geotrellis" "openeo-geotrellis-openeo-sparkapplication"
check_service_exists "openeo-geotrellis" "openeo-geotrellis-openeo-ui-svc"

check_url_status_code "$HTTP_SCHEME://openeo.$INGRESS_HOST" 200
check_url_status_code "$HTTP_SCHEME://openeo.$INGRESS_HOST/openeo/1.2/processes" 200

echo
echo "All Resources:"
echo
kubectl get all -n openeo-geotrellis
echo
echo "✅ openEO validation succeeded."
