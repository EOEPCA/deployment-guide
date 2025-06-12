#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source ~/.eoepca/state

echo "🔍 Validating IAM deployment..."

# Validate Keycloak
check_pods_running "iam" "app.kubernetes.io/name=keycloak" 1
check_statefulset_ready "iam" "iam-keycloak"
check_statefulset_ready "iam" "iam-postgresql"

check_service_exists "iam" "iam-keycloak-headless"
check_service_exists "iam" "iam-keycloak"
check_service_exists "iam" "identity-api"

# Validate Keycloak realm 'eoepca'
echo "Validating Keycloak realm 'eoepca' exists..."
ACCESS_TOKEN=$( \
  curl -k --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/master/protocol/openid-connect/token" | jq -r '.access_token' \
)

REALM_EXISTS=$(curl -k --silent --show-error \
  -X GET \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${HTTP_SCHEME}://${KEYCLOAK_HOST}/admin/realms/${REALM}" \
  -o /dev/null -w '%{http_code}')

if [ "$REALM_EXISTS" -eq 200 ]; then
  echo "✅ Keycloak realm 'eoepca' exists."
else
  echo "❌ Keycloak realm 'eoepca' does not exist."
fi

# Validate Keycloak client 'opa'
echo "Validating Keycloak client 'opa' exists..."
OPA_CLIENT_ID="$( \
  curl -k --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients" \
    | jq -r '.[] | select(.clientId == "opa") | .id' \
)"

if [ -n "$OPA_CLIENT_ID" ]; then
  echo "✅ Keycloak client 'opa' exists."
else
  echo "❌ Keycloak client 'opa' does not exist."
fi

# Validate Keycloak client 'identity-api'
echo "Validating Keycloak client 'identity-api' exists..."
IDENTITY_API_CLIENT_ID="$( \
  curl -k --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients" \
    | jq -r '.[] | select(.clientId == "identity-api") | .id' \
)"

if [ -n "$IDENTITY_API_CLIENT_ID" ]; then
  echo "✅ Keycloak client 'identity-api' exists."
else
  echo "❌ Keycloak client 'identity-api' does not exist."
fi

echo
echo "All Resources:"
echo
kubectl get all -n iam