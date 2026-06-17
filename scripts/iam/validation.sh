#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source ~/.eoepca/state

echo "🔍 Validating IAM deployment..."

check_secret_exists "iam" "keycloak-admin"
check_secret_exists "iam" "postgresql"
check_secret_exists "iam" "keycloak-provider"
check_secret_exists "iam" "opa-route"
check_secret_exists "iam-management" "keycloak-provider"

# Validate Keycloak Operator, Keycloak and PostgreSQL
check_deployment_ready "iam" "iam-keycloak-operator-operator"
if kubectl wait -n iam --for=condition=Ready keycloak.k8s.keycloak.org/iam-keycloak-operator --timeout=60s >/dev/null 2>&1; then
  echo "✅ Keycloak custom resource is ready."
else
  echo "❌ Keycloak custom resource is not ready."
fi
check_statefulset_ready "iam" "iam-postgresql"

check_service_exists "iam" "iam-keycloak-operator-service"
check_service_exists "iam" "iam-postgresql"
check_service_exists "iam" "iam-opa"
check_deployment_ready "iam" "iam-opa"
check_deployment_ready "iam" "iam-opal-client"
check_deployment_ready "iam" "iam-opal-server"

check_crd_exists "providerconfigs.keycloak.m.crossplane.io"
check_crd_exists "clients.openidclient.keycloak.m.crossplane.io"

# Validate Keycloak realm
echo "Validating Keycloak realm '${REALM}' exists..."
ACCESS_TOKEN=$( \
  curl -k --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/master/protocol/openid-connect/token" | jq -r '.access_token' \
)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "❌ Could not obtain a Keycloak admin access token."
  echo "   Check the Keycloak route and the keycloak-admin secret."
  exit 1
fi

REALM_EXISTS=$(curl -k --silent --show-error \
  -X GET \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${HTTP_SCHEME}://${KEYCLOAK_HOST}/admin/realms/${REALM}" \
  -o /dev/null -w '%{http_code}')

if [ "$REALM_EXISTS" -eq 200 ]; then
  echo "✅ Keycloak realm '${REALM}' exists."
else
  echo "❌ Keycloak realm '${REALM}' does not exist."
fi

echo "Validating Keycloak client '${OPA_CLIENT_ID}' exists..."
OPA_CLIENT_UUID="$( \
  curl -k --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients" \
    | jq -r --arg client_id "${OPA_CLIENT_ID:-opa}" '.[] | select(.clientId == $client_id) | .id' \
)"

if [ -n "$OPA_CLIENT_UUID" ]; then
  echo "✅ Keycloak client '${OPA_CLIENT_ID:-opa}' exists."
else
  echo "❌ Keycloak client '${OPA_CLIENT_ID:-opa}' does not exist."
fi

echo
echo "All Resources:"
echo
kubectl get all -n iam
