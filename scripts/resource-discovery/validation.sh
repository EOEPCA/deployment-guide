#!/bin/bash

set -euo pipefail

source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "resource-discovery" "io.kompose.service=pycsw" 1
check_deployment_ready "resource-discovery" "resource-catalogue-service"

check_service_exists "resource-discovery" "resource-catalogue-db"
check_service_exists "resource-discovery" "resource-catalogue-service"

check_url_status_code "$HTTP_SCHEME://resource-catalogue.$INGRESS_HOST/" "200"
check_url_status_code "$HTTP_SCHEME://resource-catalogue.$INGRESS_HOST/conformance" "200"
check_url_status_code "$HTTP_SCHEME://resource-catalogue.$INGRESS_HOST/collections" "200"

check_pvc_bound "resource-discovery" "db-data-resource-catalogue-db-0"

check_configmap_exists "resource-discovery" "resource-catalogue-db-configmap"
check_configmap_exists "resource-discovery" "resource-catalogue-configmap"

if [ "${RESOURCE_DISCOVERY_ENABLE_IAM:-no}" = "yes" ]; then
  echo
  echo "Validating protected Resource Discovery resources..."

  check_pods_running "resource-discovery" "io.kompose.service=pycsw-protected" 1
  check_deployment_ready "resource-discovery" "resource-catalogue-protected-service"

  check_service_exists "resource-discovery" "resource-catalogue-protected-service"
  check_configmap_exists "resource-discovery" "resource-catalogue-protected-configmap"

  # Public paths on the protected catalogue should be reachable without login.
  check_url_status_code "$HTTP_SCHEME://resource-catalogue-protected.$INGRESS_HOST/conformance" "200"

  # The protected root is expected to redirect to IAM, not return 200.
  check_url_status_code "$HTTP_SCHEME://resource-catalogue-protected.$INGRESS_HOST/" "302"
fi

echo
echo "All Resources:"
echo
kubectl get all -n resource-discovery