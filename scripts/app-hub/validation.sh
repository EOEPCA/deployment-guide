#!/bin/bash
set -e

source ../common/utils.sh
source ../common/validation-utils.sh

NAMESPACE="app-hub"
APPHUB_PUBLIC_HOST="${APPHUB_PUBLIC_HOST:-app-hub.${INGRESS_HOST}}"
APPHUB_CLIENT_ID="${APPHUB_CLIENT_ID:-application-hub}"

check_secret_exists "${NAMESPACE}" "application-hub"

check_keycloak_provider_config_exists "iam-management" "keycloak-provider-config"
check_keycloak_client_secret_exists "iam-management" "${APPHUB_CLIENT_ID}"
check_keycloak_client_ready "iam-management" "${APPHUB_CLIENT_ID}" "Apply scripts/app-hub/generated-iam.yaml and check Crossplane reconciliation."

check_daemonset_ready "${NAMESPACE}" "application-hub-continuous-image-puller"

check_deployment_ready "${NAMESPACE}" "application-hub-proxy"
check_deployment_ready "${NAMESPACE}" "application-hub-user-scheduler"
check_deployment_ready "${NAMESPACE}" "application-hub-hub"

check_service_exists "${NAMESPACE}" "application-hub-proxy-public"
check_service_exists "${NAMESPACE}" "application-hub-proxy-api"
check_service_exists "${NAMESPACE}" "application-hub-hub"

check_url_status_code "$HTTP_SCHEME://${APPHUB_PUBLIC_HOST}/hub/login" "200"

check_pvc_bound "${NAMESPACE}" "application-hub-hub-db-dir"

echo
echo "All Resources:"
echo
kubectl get all -l release=application-hub -n "${NAMESPACE}"
