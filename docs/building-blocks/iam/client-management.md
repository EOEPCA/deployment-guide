> **Note:** If the EOEPCA IAM Building Block is required during deployment, specific steps will be provided in the relevant sections of the building block deployment guide. This section serves as a reference and is applicable only if you're using the EOEPCA IAM Building Block. Ensure the EOEPCA IAM Building Block is installed. For more information, refer to [this guide](./main-iam.md).


This document details how to manage Keycloak clients programmatically, obtain tokens, and perform device flows. Clients represent applications or services interacting with EOEPCA’s secured endpoints.


## Creating a Keycloak Client

### Using the Script

Use the `create-client.sh` script in the `/scripts/utils/` directory. This script prompts you for basic details and automatically creates a Keycloak client in your chosen realm:

```bash
cd deployment-guide/scripts/utils
bash create-client.sh
```

When prompted:

- **Keycloak Admin Username and Password**: Provide the credentials for your Keycloak administrator account. These credentials are typically stored in `~/.eoepca/state` if configured.
- **Keycloak Base Domain**: The domain where your Keycloak server is hosted, for example, `auth.example.com`.
- **Realm**: The specific realm within Keycloak where the client will be created, such as `eoepca`.
- **Client ID**: A unique identifier for your client application, for example, `my-client-app`.
- **Client Name and Description**: Descriptive texts to identify your client application, like `My Client Application`.
- **Client Secret**: A secret key associated with your client. During the Building Block installations, these will be set for you.
- **Subdomain**: A designated subdomain for your client application, for instance, `app`.

After it completes, you should see a JSON snippet confirming the newly created client.


### Manually

**Obtain Admin Token**:

```bash
source ~/.eoepca/state # This will set KEYCLOAK_ADMIN_USER and KEYCLOAK_ADMIN_PASSWORD into your environment

ACCESS_TOKEN=$( \
  curl --silent --show-error \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://auth.<YOUR DOMAIN>/realms/master/protocol/openid-connect/token" \
  | jq -r '.access_token' \
)
```

**Create a Client**:

> You can leave the "secret" field empty to have Keycloak generate a random secret. Just ensure you retrieve it for future use. If you do provide the secret, ensure it is formatted correctly.

```bash
curl --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://auth.<YOUR DOMAIN>/admin/realms/eoepca/clients" <<EOF
{
  "clientId": "<UPDATE TO CLIENT ID>",
  "name": "<UPDATE TO CLIENT NAME>",
  "description": "<A SENSIBLE DESCRIPTION>",
  "enabled": true,
  "protocol": "openid-connect",
  "rootUrl": "<UPDATE TO MAIN URL OF THE CLIENT>",
  "baseUrl": "<UPDATE TO MAIN URL OF THE CLIENT>",
  "redirectUris": ["https://<UPDATE TO THE MAIN URL OF THE CLIENT>/*", "/*"],
  "webOrigins": ["/*"],
  "publicClient": false,
  "clientAuthenticatorType": "client-secret",
  "secret": "<OPTIONAL SECRET, OR LEAVE EMPTY>",
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
  "https://auth.<YOUR DOMAIN>/admin/realms/eoepca/clients" \
| jq '.[] | select(.clientId == "<UPDATE TO CLIENT ID>")'
```

## Deleting a Client

First, get the client’s unique ID:

```bash
myclient_id=$( \
  curl --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://auth.<YOUR DOMAIN>/admin/realms/eoepca/clients" \
  | jq -r '.[] | select(.clientId == "<UPDATE TO CLIENT ID>") | .id' \
)
```

Delete the client:

```bash
curl --silent --show-error \
  -X DELETE \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://auth.<YOUR DOMAIN>/admin/realms/eoepca/clients/${<UPDATE TO CLIENT ID>}"
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
    -d "client_id=<UPDATE TO CLIENT ID>" \
    -d "client_secret=<UPDATE TO CLIENT SECRET>" \
    -d "scope=openid profile email" \
    "https://auth.<YOUR DOMAIN>/realms/eoepca/protocol/openid-connect/auth/device" \
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
    -d "client_id=<UPDATE TO CLIENT ID>" \
    -d "client_secret=<UPDATE TO CLIENT SECRET>" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    -d "device_code=${device_code}" \
    "https://auth.<YOUR DOMAIN>/realms/eoepca/protocol/openid-connect/token" \
)
access_token=$(echo $response | jq -r '.access_token')
refresh_token=$(echo $response | jq -r '.refresh_token')
id_token=$(echo $response | jq -r '.id_token')
```

Use this `access_token` in `Authorization: Bearer` headers for requests to protected resources.
