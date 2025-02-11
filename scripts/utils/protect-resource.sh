#!/usr/bin/env bash

# Set working directory for relative paths
ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"
trap "cd '${ORIG_DIR}'" EXIT

source '../common/utils.sh'

# Ask for Keycloak details
ask "KEYCLOAK_ADMIN_USER" "Keycloak Admin Username" "${KEYCLOAK_ADMIN_USER}"
ask "KEYCLOAK_ADMIN_PASSWORD" "Keycloak Admin Password" "${KEYCLOAK_ADMIN_PASSWORD}"
ask "KEYCLOAK_HOST" "Enter the Keycloak base domain (e.g. auth-apx.example.com)" "auth-apx.example.com" is_valid_domain
ask "REALM" "Enter the Keycloak Realm name" "eoepca"

# Ask for details of the required protection
ask_temp "CLIENT_ID" "Enter the Client ID that needs resource protection (e.g. myclient)" "myclient"
ask_temp "USER_NAME" "Enter the username to receive access" "${KEYCLOAK_TEST_USER:-eoepcauser}"
ask_temp "DISPLAY_NAME" "Enter a display name for the protection (e.g. protection summary)" "${USER_NAME}"
ask_temp "RESOURCE_TYPE" "Enter the type of the resource (e.g. urn:your-client-id:resources:default)" "urn:${CLIENT_ID}:resources:default"
ask_temp "RESOURCE_URI" "Enter the URI path to protect (e.g. /healthcheck)" "/${USER_NAME}/*"

# Deduce names of Keycloak artifacts to be created
GROUP_NAME="${DISPLAY_NAME}-group"
POLICY_NAME="${DISPLAY_NAME}-policy"
RESOURCE_NAME="${DISPLAY_NAME}-resource"
PERMISSION_NAME="${DISPLAY_NAME}-access"

# Obtain Admin Token
ACCESS_TOKEN=$(
    curl --silent --show-error \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${KEYCLOAK_ADMIN_USER}" \
        -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" \
        "https://${KEYCLOAK_HOST}/realms/master/protocol/openid-connect/token" |
        jq -r '.access_token'
)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "ERROR: Failed to obtain an admin access token. Check credentials."
    exit 1
fi

# 1. Create the Group
echo "Creating group: ${GROUP_NAME}"
curl --silent --show-error \
    -X POST "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/groups" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -d "{\"name\": \"${GROUP_NAME}\"}"

# Get the group ID
group_id=$(
    curl --silent --show-error \
        -X GET "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/groups" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" |
        jq -r ".[] | select(.name == \"${GROUP_NAME}\") | .id"
)
echo "Group ID: ${group_id}"

if [ -z "$group_id" ]; then
    echo "ERROR: Group could not be created or found. Exiting."
    exit 1
fi

# 2. Add a User to the Group
echo "Retrieving user ID of ${USER_NAME}"
user_id=$(
    curl --silent --show-error \
        -X GET "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/users?username=${USER_NAME}" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" |
        jq -r '.[0].id'
)
echo "User ID: ${user_id}"

if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
    echo "ERROR: Could not find user ${USER_NAME}. Make sure the user exists."
    exit 1
fi

echo "Adding user ${USER_NAME} (ID: ${user_id}) to group ${GROUP_NAME} (ID: ${group_id})"
curl --silent --show-error \
    -X PUT "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/users/${user_id}/groups/${group_id}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}"

# 3. Create a Policy for the group
echo "Retrieving internal client ID for client: ${CLIENT_ID}"
internal_client_id=$(
    curl --silent --show-error \
        -X GET "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" |
        jq -r ".[] | select(.clientId == \"${CLIENT_ID}\") | .id"
)
if [ -z "$internal_client_id" ] || [ "$internal_client_id" = "null" ]; then
    echo "ERROR: Could not find client '${CLIENT_ID}' in realm '${REALM}'."
    exit 1
fi

echo "Creating group-based policy: ${POLICY_NAME}"
policy_id=$(
    curl --silent --show-error \
        -X POST "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients/${internal_client_id}/authz/resource-server/policy/group" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -d @- <<EOF | jq -r '.id'
{
  "name": "${POLICY_NAME}",
  "logic": "POSITIVE",
  "decisionStrategy": "UNANIMOUS",
  "groups": ["${group_id}"]
}
EOF
)

echo "Policy ID: ${policy_id}"
if [ -z "$policy_id" ] || [ "$policy_id" = "null" ]; then
    echo "ERROR: Policy creation failed."
    exit 1
fi

# 4. Create a Resource
echo "Creating resource ${RESOURCE_NAME} for URI ${RESOURCE_URI}"
resource_id=$(
    curl --silent --show-error \
        -X POST "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients/${internal_client_id}/authz/resource-server/resource" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -d @- <<EOF | jq -r '._id'
{
  "name": "${RESOURCE_NAME}",
  "type": "${RESOURCE_TYPE}",
  "uris": ["${RESOURCE_URI}"],
  "ownerManagedAccess": true
}
EOF
)
echo "Resource ID: ${resource_id}"
if [ -z "$resource_id" ] || [ "$resource_id" = "null" ]; then
    echo "ERROR: Resource creation failed."
    exit 1
fi

# 5. Create a Permission linking the policy & resource
echo "Creating permission: ${PERMISSION_NAME}"
permission_id=$(
    curl --silent --show-error \
        -X POST "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients/${internal_client_id}/authz/resource-server/policy/resource" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -d @- <<EOF | jq -r '.id'
{
  "name": "${PERMISSION_NAME}",
  "description": "Group ${GROUP_NAME} access to ${RESOURCE_URI}",
  "logic": "POSITIVE",
  "decisionStrategy": "UNANIMOUS",
  "resources": ["${resource_id}"],
  "policies": ["${policy_id}"]
}
EOF
)
echo "Permission ID: ${permission_id}"
if [ -z "$permission_id" ] || [ "$permission_id" = "null" ]; then
    echo "ERROR: Permission creation failed."
    exit 1
fi

echo "Done! The group ${GROUP_NAME} can now access ${RESOURCE_URI} in client ${CLIENT_ID}."
