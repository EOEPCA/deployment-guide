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

# Confirms pycsw actually picked up `distributedsearch.catalogues` - a
# top-level `federatedcatalogues` key is silently ignored, so this would
# come back empty if that config key regressed.
if curl -s "$HTTP_SCHEME://resource-catalogue.$INGRESS_HOST/collections/metadata:main/federatedCatalogs?f=json" | grep -q "fedcat01"; then
  echo "✅ Federated catalogues (distributedsearch.catalogues) are configured and exposed."
else
  echo "❌ No federated catalogues found at /collections/metadata:main/federatedCatalogs - check pycsw.config.distributedsearch.catalogues in generated-values.yaml."
fi

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
  check_secret_exists "resource-discovery" "resource-catalogue-db-secret"

  check_keycloak_client_ready "iam-management" "resource-catalogue" \
    "Apply scripts/resource-discovery/generated-iam.yaml and check Crossplane reconciliation."

  # Public paths on the protected catalogue should be reachable without login.
  check_url_status_code "$HTTP_SCHEME://resource-catalogue-protected.$INGRESS_HOST/conformance" "200"

  # The protected root is expected to redirect to IAM, not return 200.
  CHECK_URL_NO_REDIRECT=true check_url_status_code "$HTTP_SCHEME://resource-catalogue-protected.$INGRESS_HOST/" "302"
fi

echo
echo "All Resources:"
echo
kubectl get all -n resource-discovery