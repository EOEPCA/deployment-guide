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
check_crd_exists "users.user.keycloak.m.crossplane.io"

if kubectl wait -n iam --for=condition=complete job/eoepca-realm --timeout=60s >/dev/null 2>&1; then
  echo "✅ Realm import job 'eoepca-realm' completed."
else
  echo "❌ Realm import job 'eoepca-realm' has not completed."
  echo "   Check: kubectl logs -n iam job/eoepca-realm"
fi

check_keycloak_user_ready "iam-management" "eoepca-user" \
  "Apply generated-eoepca-user.yaml (rendered from eoepca-user-template.yaml) after configure-iam.sh and apply-secrets.sh."

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

echo "Validating test user '${KEYCLOAK_TEST_USER}' can log in..."
USER_TOKEN_RESPONSE=$( \
  curl -k --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_TEST_USER}" \
    --data-urlencode "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    -d "scope=openid" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" \
)
USER_ACCESS_TOKEN=$(echo "$USER_TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$USER_ACCESS_TOKEN" ] || [ "$USER_ACCESS_TOKEN" = "null" ]; then
  echo "❌ Test user '${KEYCLOAK_TEST_USER}' could not log in."
  echo "   Check the Crossplane User 'eoepca-user' in namespace 'iam-management' and its 'eoepca-user' secret."
else
  # admin-cli issues lightweight access tokens (no identity claims, and rejected
  # by /userinfo) - decode the id_token instead to confirm the identity claims.
  ID_TOKEN_PAYLOAD=$(echo "$USER_TOKEN_RESPONSE" | jq -r '.id_token' | cut -d. -f2 | tr '_-' '/+')
  case $(( ${#ID_TOKEN_PAYLOAD} % 4 )) in
    2) ID_TOKEN_PAYLOAD="${ID_TOKEN_PAYLOAD}==" ;;
    3) ID_TOKEN_PAYLOAD="${ID_TOKEN_PAYLOAD}=" ;;
  esac
  ID_TOKEN_USERNAME=$(echo "$ID_TOKEN_PAYLOAD" | base64 -d 2>/dev/null | jq -r '.preferred_username')

  if [ "$ID_TOKEN_USERNAME" = "$KEYCLOAK_TEST_USER" ]; then
    echo "✅ Test user '${KEYCLOAK_TEST_USER}' obtained a token and its id_token identity claims match."
  else
    echo "❌ Test user token's id_token 'preferred_username' ('${ID_TOKEN_USERNAME}') does not match '${KEYCLOAK_TEST_USER}'."
  fi
fi

echo
echo "All Resources:"
echo
kubectl get all -n iam
