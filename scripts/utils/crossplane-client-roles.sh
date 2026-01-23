#!/usr/bin/env bash

# Set working directory for relative paths
ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"
trap "cd '${ORIG_DIR}'" EXIT

source "$HOME/.eoepca/state"

CLIENT_ID="$1"
if [ -z "$CLIENT_ID" ]; then
    echo "ERROR: CLIENT_ID argument is required." 1>&2
    echo "Usage: $(basename "$0") <CLIENT_ID>"
    exit 1
fi

echo "Assigning realm-management roles to the service account of client ${CLIENT_ID} ..."

# Obtain Admin Token
ACCESS_TOKEN=$(
    curl -k --silent --show-error \
        -X POST \
        -d "username=${KEYCLOAK_ADMIN_USER}" \
        --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" \
        "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/master/protocol/openid-connect/token" |
        jq -r '.access_token'
)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "ERROR: Failed to obtain an admin access token. Check credentials."
    exit 1
fi

echo "Obtained Admin Token successfully: ${ACCESS_TOKEN:0:10}..."

# Get client UUID
CLIENT_UUID=$(curl -s -X GET \
-H "Authorization: Bearer $ACCESS_TOKEN" \
"$HTTP_SCHEME://$KEYCLOAK_HOST/admin/realms/$REALM/clients?clientId=$CLIENT_ID" \
| jq -r '.[0].id')

if [ -z "$CLIENT_UUID" ] || [ "$CLIENT_UUID" = "null" ]; then
    echo "ERROR: Failed to obtain client UUID for client ID $CLIENT_ID." 1>&2
    exit 1
else
    echo "Client UUID: $CLIENT_UUID"
fi

# Get service account user ID
SERVICE_ACCOUNT_USER_ID=$(curl -s -X GET \
-H "Authorization: Bearer $ACCESS_TOKEN" \
"$HTTP_SCHEME://$KEYCLOAK_HOST/admin/realms/$REALM/clients/$CLIENT_UUID/service-account-user" \
| jq -r '.id')

if [ -z "$SERVICE_ACCOUNT_USER_ID" ] || [ "$SERVICE_ACCOUNT_USER_ID" = "null" ]; then
    echo "ERROR: Failed to obtain service account user ID for client ID $CLIENT_ID." 1>&2
    exit 1
else
    echo "Service account user ID: $SERVICE_ACCOUNT_USER_ID"
fi

# Get realm-management client UUID
REALM_MGMT_UUID=$(curl -s -X GET \
-H "Authorization: Bearer $ACCESS_TOKEN" \
"$HTTP_SCHEME://$KEYCLOAK_HOST/admin/realms/$REALM/clients?clientId=realm-management" \
| jq -r '.[0].id')

if [ -z "$REALM_MGMT_UUID" ] || [ "$REALM_MGMT_UUID" = "null" ]; then
    echo "ERROR: Failed to obtain realm-management client UUID." 1>&2
    exit 1
else
    echo "Realm-management client UUID: $REALM_MGMT_UUID"
fi

# Resolve multiple role UUIDs
ROLES=("manage-users" "manage-clients" "manage-authorization" "create-client" "manage-realm")

ROLE_PAYLOAD="[]"
for ROLE_NAME in "${ROLES[@]}"; do
    ROLE_JSON=$(curl -s -X GET \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        "$HTTP_SCHEME://$KEYCLOAK_HOST/admin/realms/$REALM/clients/$REALM_MGMT_UUID/roles/$ROLE_NAME")

    ROLE_ID=$(echo "$ROLE_JSON" | jq -r '.id')

    ROLE_OBJ=$(jq -n \
        --arg id "$ROLE_ID" \
        --arg name "$ROLE_NAME" \
        --arg containerId "$REALM_MGMT_UUID" \
        '{id: $id, name: $name, composite: false, clientRole: true, containerId: $containerId}')

    ROLE_PAYLOAD=$(echo "$ROLE_PAYLOAD" | jq ". + [$ROLE_OBJ]")
done

# Assign roles to service account user
curl -s -X POST \
-H "Authorization: Bearer $ACCESS_TOKEN" \
-H "Content-Type: application/json" \
-d "$ROLE_PAYLOAD" \
"$HTTP_SCHEME://$KEYCLOAK_HOST/admin/realms/$REALM/users/$SERVICE_ACCOUNT_USER_ID/role-mappings/clients/$REALM_MGMT_UUID"

echo "Assigned roles ${ROLES[*]} to service account user $SERVICE_ACCOUNT_USER_ID"
