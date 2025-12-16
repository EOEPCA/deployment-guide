> **Note:** If the EOEPCA IAM Building Block is required during deployment, specific steps will be provided in the relevant sections of the building block deployment guide. This section serves as a reference and is applicable only if you're using the EOEPCA IAM Building Block. Ensure the EOEPCA IAM Building Block is installed. For more information, refer to [this guide](./main-iam.md).


This document details how to manage Keycloak clients programmatically, obtain tokens, and perform device flows. Clients represent applications or services interacting with EOEPCA's secured endpoints.


## Creating a Keycloak Client

Three alternative paths are offered for creation of Keycloak clients:

1. Using the Keycloak Provider for Crossplane (recommended for infrastructure as code setups)
2. Using the provided script (suitable for quick setups or manual processes)
3. Manually via Keycloak's REST API (for advanced users needing fine control)

### Approach 1: Using the Keycloak Provider for Crossplane (Recommended)

If you have Crossplane set up with the Keycloak provider, you can create a Keycloak client using a Kubernetes Custom Resource Definition (CRD). This assumes you have followed the steps:

* [Crossplane deployment](../../prerequisites/crossplane.md)
* [Keycloak Management via Crossplane](../iam/main-iam.md#5-establish-keycloak-management-via-crossplane)

> Note the use of placeholders such as `<client-name>`, `<client-secret>`, `<service-name>`, etc.. Replace these with actual values relevant to your setup.

**Confidential Client**

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: <client-name>-keycloak-client
  namespace: iam-management
stringData:
  client_secret: <client-secret>
---
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: <client-name>
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: <client-name>
    name: <Descriptive Client Name>
    description: <Description of the Client Purpose>
    enabled: true
    accessType: CONFIDENTIAL
    rootUrl: ${HTTP_SCHEME}://<service-name>.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://<service-name>.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://<service-name>.${INGRESS_HOST}
    serviceAccountsEnabled: true
    directAccessGrantsEnabled: true
    standardFlowEnabled: true
    oauth2DeviceAuthorizationGrantEnabled: true
    useRefreshTokens: true
    authorization:
      - allowRemoteResourceManagement: false
        decisionStrategy: UNANIMOUS
        keepDefaults: true
        policyEnforcementMode: ENFORCING
    validRedirectUris:
      - "/*"
    webOrigins:
      - "/*"
    clientSecretSecretRef:
      name: <client-name>-keycloak-client
      key: client_secret
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

**Public Client**

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: <client-name>
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: <client-name>
    name: <Descriptive Client Name>
    description: <Description of the Client Purpose>
    enabled: true
    accessType: PUBLIC
    rootUrl: ${HTTP_SCHEME}://<service-name>.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://<service-name>.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://<service-name>.${INGRESS_HOST}
    directAccessGrantsEnabled: true
    standardFlowEnabled: true
    oauth2DeviceAuthorizationGrantEnabled: true
    useRefreshTokens: true
    validRedirectUris:
      - "/*"
      - "https://editor.openeo.org/*"
    webOrigins:
      - "+"
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

### Approach 2: Using the Script

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
- **Subdomain**: A designated subdomain for your client application (for auth flow redirection), for instance, `app`.
- **Additional Subdomains**: Additional allowed subdomains (for auth flow redirection), if required - otherwise leave blank.
- **Additional Hosts**: Additional allowed full hostnames (for auth flow redirection), if required - otherwise leave blank.

After it completes, you should see a JSON snippet confirming the newly created client.


### Approach 3: Manually

**Obtain Admin Token**:

```bash
source ~/.eoepca/state # This will set KEYCLOAK_ADMIN_USER and KEYCLOAK_ADMIN_PASSWORD into your environment

ACCESS_TOKEN=$( \
  curl --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/token" \
  | jq -r '.access_token' \
)
echo ${ACCESS_TOKEN}
```

**Create a Client**:

> You can leave the "secret" field empty to have Keycloak generate a random secret. Just ensure you retrieve it for future use. If you do provide the secret, ensure it is formatted correctly.

```bash
curl --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/clients" <<EOF
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
  "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/clients" \
| jq '.[] | select(.clientId == "<UPDATE TO CLIENT ID>")'
```

## Deleting a Client

**Managed Resource**

In the case that the Client was created via Crossplane CRD (`Approach 1`), then it is a managed Kubernetes resource. In this case, simply delete the CRD resource, which will trigger the Keycloak Provider to delete the client from Keycloak:

```bash
kubectl delete client.openidclient.keycloak.m.crossplane.io <client-name> -n iam-management
```

**Keycloak API**

Otherwise (`Approaches 2/3`), the client can be deleted manually via the Keycloak REST API.

First, get the client's unique ID:

```bash
myclient_id=$( \
  curl --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/clients" \
  | jq -r '.[] | select(.clientId == "<UPDATE TO CLIENT ID>") | .id' \
)
```

Delete the client:

```bash
curl --silent --show-error \
  -X DELETE \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/clients/${<UPDATE TO CLIENT ID>}"
```

## Obtaining Tokens via the Device Flow

The device flow is handy for CLI tools or Jupyter notebooks, where a user can log in via a browser while the tool waits for a token.

**Step 1: Initiate Device Auth Flow**

```bash
source ~/.eoepca/state

response=$( \
  curl --silent --show-error \
    -X POST \
    -d "client_id=<UPDATE TO CLIENT ID>" \
    --data-urlencode "client_secret=<UPDATE TO CLIENT SECRET>" \
    -d "scope=openid profile email" \
    "https://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/auth/device" \
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
    -d "client_id=<UPDATE TO CLIENT ID>" \
    --data-urlencode "client_secret=<UPDATE TO CLIENT SECRET>" \
    -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
    -d "device_code=${device_code}" \
    "https://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/token" \
)
access_token=$(echo $response | jq -r '.access_token')
refresh_token=$(echo $response | jq -r '.refresh_token')
id_token=$(echo $response | jq -r '.id_token')
```

Use this `access_token` in `Authorization: Bearer` headers for requests to protected resources.
