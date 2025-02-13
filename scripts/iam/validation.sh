#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

echo "🔍 Validating IAM deployment..."

# Validate Keycloak
check_pods_running "iam" "app.kubernetes.io/name=keycloak" 1
check_statefulset_ready "iam" "keycloak"

check_service_exists "iam" "keycloak"
check_service_exists "iam" "keycloak-postgresql"

check_url_status_code "$HTTP_SCHEME://auth.$INGRESS_HOST" "200"

# Validate OPA
check_pods_running "iam" "app.kubernetes.io/name=opa-opal-client" 1
check_deployment_ready "iam" "opa-opal-client"
check_service_exists "iam" "opa-opal-client"

check_pods_running "iam" "app.kubernetes.io/name=opa-opal-server" 1
check_deployment_ready "iam" "opa-opal-server"
check_service_exists "iam" "opa-opal-server"

check_url_status_code "$HTTP_SCHEME://opa.$INGRESS_HOST/healthcheck" "200"

check_pvc_bound "iam" "data-keycloak-postgresql-0"


# Validate Keycloak realm 'eoepca'
echo "Validating Keycloak realm 'eoepca' exists..."
ACCESS_TOKEN=$( \
  curl --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://auth.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" | jq -r '.access_token' \
)

REALM_EXISTS=$(curl --silent --show-error \
  -X GET \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://auth.${INGRESS_HOST}/admin/realms/${REALM}" \
  -o /dev/null -w '%{http_code}')

if [ "$REALM_EXISTS" -eq 200 ]; then
  echo "✅ Keycloak realm 'eoepca' exists."
else
  echo "❌ Keycloak realm 'eoepca' does not exist."
fi

# Validate Keycloak client 'opa'
echo "Validating Keycloak client 'opa' exists..."
OPA_CLIENT_ID="$( \
  curl --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/clients" \
    | jq -r '.[] | select(.clientId == "opa") | .id' \
)"

if [ -n "$OPA_CLIENT_ID" ]; then
  echo "✅ Keycloak client 'opa' exists."
else
  echo "❌ Keycloak client 'opa' does not exist."
fi


echo
echo "All Resources:"
echo
kubectl get all -n iam