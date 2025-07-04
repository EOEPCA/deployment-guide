#!/usr/bin/env bash

# Set working directory for relative paths
ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"
trap "cd '${ORIG_DIR}'" EXIT

source '../common/utils.sh'

# Ask the user for details
ask "KEYCLOAK_ADMIN_USER" "Keycloak Admin Username" "${KEYCLOAK_ADMIN_USER}"
ask "KEYCLOAK_ADMIN_PASSWORD" "Keycloak Admin Password" "${KEYCLOAK_ADMIN_PASSWORD}"
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "KEYCLOAK_HOST" "Enter the Keycloak full hostname excluding scheme (http(s)) (e.g., auth.example.com)" "auth.${INGRESS_HOST}" is_valid_domain
ask "REALM" "Enter the Keycloak Realm name" "eoepca"
ask_temp "CONFIDENTIAL_CLIENT" "Create a CONFIDENTIAL client (true|false)? (false creates a PUBLIC client)" "true" is_boolean
PUBLIC_CLIENT="$( if [ "${CONFIDENTIAL_CLIENT}" == "true" ]; then echo "false"; else echo "true"; fi )"
ask_temp "CLIENT_ID" "Enter the new Client ID" "myclient"
ask_temp "CLIENT_NAME" "Enter a name for this client" "My Client"
ask_temp "CLIENT_DESCRIPTION" "Enter a description for this client" "A sample OIDC client"
if [ "${CONFIDENTIAL_CLIENT}" == "true" ]; then
  ask_temp "CLIENT_SECRET" "Enter the client secret" ""
fi
ask_temp "CLIENT_SUBDOMAIN" "Enter the primary subdomain for the client (e.g., myclient)" "myclient"

ask_temp "ADDITIONAL_SUBDOMAINS" "Enter additional subdomains used for the Redirect URIs, comma-separated, or leave empty (e.g., service-api,service-swagger)" ""

ask_temp "ADDITIONAL_HOSTS" "Enter additional (full) hosts used for the Redirect URIs, comma-separated, or leave empty (e.g., service.some.platform)" ""

ROOT_URL="${HTTP_SCHEME}://${CLIENT_SUBDOMAIN}.${INGRESS_HOST}"
REDIRECT_URIS=("${HTTP_SCHEME}://${CLIENT_SUBDOMAIN}.${INGRESS_HOST}/*" "/*")

REDIRECT_URIS=("${HTTP_SCHEME}://${CLIENT_SUBDOMAIN}.${INGRESS_HOST}/*")
# Subdomains
IFS=',' read -ra ADDR <<<"${ADDITIONAL_SUBDOMAINS}"
for sub in "${ADDR[@]}"; do
    REDIRECT_URIS+=("${HTTP_SCHEME}://${sub}.${INGRESS_HOST}/*")
done
# Hosts
IFS=',' read -ra HOSTS <<<"${ADDITIONAL_HOSTS}"
for host in "${HOSTS[@]}"; do
    REDIRECT_URIS+=("https://${host}/*")
done

echo "Redirect URIs: ${REDIRECT_URIS[@]}"

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

# Create the Client
echo "Creating client ${CLIENT_ID} in realm ${REALM} ..."

# Prepare JSON payload
# If CLIENT_SECRET is blank, Keycloak will generate one.
# If not blank, we set it.
client_secret_json=""
[ -n "$CLIENT_SECRET" ] && client_secret_json=", \"secret\": \"${CLIENT_SECRET}\""

create_client_payload=$(
    cat <<EOF
{
  "clientId": "${CLIENT_ID}",
  "name": "${CLIENT_NAME}",
  "description": "${CLIENT_DESCRIPTION}",
  "enabled": true,
  "protocol": "openid-connect",
  "rootUrl": "${ROOT_URL}",
  "baseUrl": "${ROOT_URL}",
  "redirectUris": $(printf '%s' "$(jq -n --argjson arr "$(jq -n '$ARGS.positional' --args "${REDIRECT_URIS[@]}")" '$arr')"),
  "webOrigins": ["/*"],
  "publicClient": ${PUBLIC_CLIENT},
  "clientAuthenticatorType": "client-secret",
  "directAccessGrantsEnabled": true,
  "attributes": {
    "oauth2.device.authorization.grant.enabled": "true"
  },
  "serviceAccountsEnabled": ${CONFIDENTIAL_CLIENT},
  "authorizationServicesEnabled": ${CONFIDENTIAL_CLIENT},
  "frontchannelLogout": true
  ${client_secret_json}
}
EOF
)

curl -k --silent --show-error \
    -X POST \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "${create_client_payload}" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients"

echo "Client creation request sent."

# Verify Creation
echo "Verifying creation of client: ${CLIENT_ID}"
curl -k --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/admin/realms/${REALM}/clients" |
    jq ".[] | select(.clientId == \"${CLIENT_ID}\")"

echo "Done. If the above JSON block is displayed, the client was created successfully."
