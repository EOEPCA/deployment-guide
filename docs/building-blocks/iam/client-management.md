This document details how to manage Keycloak clients programmatically, obtain tokens, and perform device flows. Clients represent applications or services interacting with EOEPCA’s secured endpoints.

## Creating a Keycloak Client

**Obtain Admin Token**:

```bash
source ~/.eoepca/state
ACCESS_TOKEN=$( \
  curl --silent --show-error \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://auth-apx.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" \
  | jq -r '.access_token' \
)
```

**Create a Client (`myclient`)**:

```bash
curl --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" <<EOF
{
  "clientId": "myclient",
  "name": "My Client",
  "description": "Test client created for illustration",
  "enabled": true,
  "protocol": "openid-connect",
  "rootUrl": "https://myservice-apx.${INGRESS_HOST}",
  "baseUrl": "https://myservice-apx.${INGRESS_HOST}",
  "redirectUris": ["https://myservice-apx.${INGRESS_HOST}/*", "/*"],
  "webOrigins": ["/*"],
  "publicClient": false,
  "clientAuthenticatorType": "client-secret",
  "secret": "changeme",
  "directAccessGrantsEnabled": false,
  "attributes": {
    "oauth2.device.authorization.grant.enabled": true
  },
  "serviceAccountsEnabled": true,
  "authorizationServicesEnabled": true,
  "frontchannelLogout": true
}
EOF
```

**Verify Creation**:

```bash
curl --silent --show-error \
  -X GET \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" \
| jq '.[] | select(.clientId == "myclient")'
```

## Deleting a Client

First, get the client’s unique ID:

```bash
myclient_id=$( \
  curl --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" \
  | jq -r '.[] | select(.clientId == "myclient") | .id' \
)
```

Delete the client:

```bash
curl --silent --show-error \
  -X DELETE \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients/${myclient_id}"
```

## Obtaining Tokens via the Device Flow

The device flow is handy for CLI tools or Jupyter notebooks, where a user can log in via a browser while the tool waits for a token.

**Step 1: Initiate Device Auth Flow**

```bash
source ~/.eoepca/state

response=$( \
  curl --silent --show-error \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=myclient" \
    -d "client_secret=changeme" \
    -d "scope=openid profile email" \
    "https://auth-apx.${INGRESS_HOST}/realms/eoepca/protocol/openid-connect/auth/device" \
)
device_code=$(echo $response | jq -r '.device_code')
verification_uri_complete=$(echo $response | jq -r '.verification_uri_complete')
echo "Open this URL in your browser: ${verification_uri_complete}"
```

**Step 2: Authorise in Browser**

Navigate to the `verification_uri_complete` URL. Log in as the required user.


**Step 3: Poll for Token**

```bash
response=$( \
  curl --silent --show-error \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=myclient" \
    -d "client_secret=changeme" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    -d "device_code=${device_code}" \
    "https://auth-apx.${INGRESS_HOST}/realms/eoepca/protocol/openid-connect/token" \
)
access_token=$(echo $response | jq -r '.access_token')
refresh_token=$(echo $response | jq -r '.refresh_token')
id_token=$(echo $response | jq -r '.id_token')
```

Use this `access_token` in `Authorization: Bearer` headers for requests to protected resources.
