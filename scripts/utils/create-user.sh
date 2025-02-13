#!/usr/bin/env bash

# Set working directory for relative paths
ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"
trap "cd '${ORIG_DIR}'" EXIT

source '../common/utils.sh'

# Ask the user for Keycloak and realm details
ask "KEYCLOAK_ADMIN_USER" "Keycloak Admin Username" "${KEYCLOAK_ADMIN_USER}"
ask "KEYCLOAK_ADMIN_PASSWORD" "Keycloak Admin Password" "${KEYCLOAK_ADMIN_PASSWORD}"
ask "KEYCLOAK_HOST" "Enter the Keycloak full host domain excluding https (e.g., auth.example.com)" "auth.example.com" is_valid_domain
ask "REALM" "Enter the Keycloak Realm name" "eoepca"

ask "KEYCLOAK_TEST_USER" "Enter the username for the example user" "eoepcauser"
ask "KEYCLOAK_TEST_PASSWORD" "Enter the password for the example user" "eoepcapassword"

# Obtain Admin Token (from 'master' realm)
ACCESS_TOKEN=$(curl --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://${KEYCLOAK_HOST}/realms/master/protocol/openid-connect/token" |
    jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "ERROR: Failed to obtain an admin access token. Check credentials."
    exit 1
fi

echo "Obtained Admin Token successfully: ${ACCESS_TOKEN:0:10}..."

# 1. Create the user
echo "Creating user $KEYCLOAK_TEST_USER in realm '${REALM}'..."

create_user_payload=$(
    cat <<EOF
{
  "username": "${KEYCLOAK_TEST_USER}",
  "enabled": true,
  "emailVerified": true,
  "email": "${KEYCLOAK_TEST_USER}@${INGRESS_HOST}",
  "firstName": "Eoepca",
  "lastName": "User"
}
EOF
)

# We do a POST to /admin/realms/{realm}/users to create the user.
create_user_response=$(
    curl --silent --show-error \
        -X POST \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${create_user_payload}" \
        "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/users" \
        -w "%{http_code}"
)

# If everything is successful, Keycloak returns 201 Created.
if [ "${create_user_response}" != "201" ]; then
    echo "ERROR: Could not create user. HTTP status code: ${create_user_response}"
    exit 1
fi

# 2. Retrieve the new user's ID
user_id=$(curl --silent --show-error \
    -X GET "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/users?username=${KEYCLOAK_TEST_USER}" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" |
    jq -r '.[0].id')

if [ -z "${user_id}" ] || [ "${user_id}" = "null" ]; then
    echo "ERROR: Could not retrieve the newly created user ID."
    exit 1
fi

echo "User ${KEYCLOAK_TEST_USER} created with ID: ${user_id}"

# 3. Set the password
echo "Setting password"

reset_password_payload=$(
    cat <<EOF
{
  "type": "password",
  "value": "${KEYCLOAK_TEST_PASSWORD}",
  "temporary": false
}
EOF
)

password_response=$(
    curl --silent --show-error \
        -X PUT \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${reset_password_payload}" \
        "https://${KEYCLOAK_HOST}/admin/realms/${REALM}/users/${user_id}/reset-password" \
        -w "%{http_code}"
)

if [ "${password_response}" != "204" ]; then
    echo "ERROR: Could not set password. HTTP status code: ${password_response}"
    exit 1
fi

echo "Password for user set successfully."

# 4. Confirmation
echo "✅ User ${KEYCLOAK_TEST_USER} created successfully in realm '${REALM}' with password ${KEYCLOAK_TEST_PASSWORD}"
exit 0
