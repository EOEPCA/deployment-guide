# Identity and Access Management (IAM) Deployment Guide

The **Identity and Access Management (IAM)** Building Block provides authentication and authorisation services within the EOEPCA+ ecosystem. It ensures users can access resources and services safely across the platform by managing identities, roles and permissions.

### Key Components

- **Keycloak**: An open-source identity and access management solution that handles user authentication and authorisation. It supports standard protocols like OpenID Connect (OIDC), OAuth 2.0, and SAML and allows for identity federation with external identity providers (IdPs) such as Google and GitHub.
    
- **Open Policy Agent (OPA)**: A policy engine used for fine-grained policy decisions. OPA evaluates policies written in a declarative language called Rego.
    
- **Open Policy Administration Layer (OPAL)**: Acts as a management layer for OPA, synchronising policies and related data from a Git repository.

- **Keycloak-OPA Adapter Plugin**: Integrates Keycloak with OPA, allowing Keycloak to delegate policy evaluations to OPA.
    
- **APISIX Ingress Controller**: Serves as the Policy Enforcement Point (PEP), acting as a reverse proxy to enforce authentication and authorisation policies before requests reach the services.


---

## Prerequisites

| Component          | Requirement                            | Documentation Link                                                |
| ------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.28)              | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)             |
| Helm               | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller   | Properly installed                     | [Installation Guide](../infra/ingress-controller.md)  |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../infra/tls/overview.md/) |

**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/iam
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

---

## Deployment Steps


### 1. Configure the IAM Deployment

Run the configuration script to collect user inputs and generate the necessary configuration files.

```bash
bash configure-iam.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - _Example_: `example.com`
- **`STORAGE_CLASS`**: Kubernetes storage class for persistent volumes.
    - _Example_: `standard`

The script will also generate secure passwords for:

- **`KEYCLOAK_ADMIN_PASSWORD`**: Password for the Keycloak admin account.
- **`KEYCLOAK_POSTGRES_PASSWORD`**: Password for the Keycloak PostgreSQL database.

These credentials will be stored in a state file at `~/.eoepca/state`.

### 2. Install APISIX Ingress Controller

If you haven't installed the APISIX Ingress Controller, follow these steps to install it in your cluster.

Refer to the [APISIX Ingress Controller Deployment Guide](../infra/ingress-controller.md#apisix-ingress-controller) for detailed instructions.

### 3. Apply Secrets

```bash
bash apply-secrets.sh
```

This script reads credentials from the state file and creates the necessary Kubernetes secrets.

### 4. Deploy Keycloak

**Install Keycloak using Helm:**

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami && \
helm repo update bitnami && \
helm upgrade -i keycloak bitnami/keycloak \
  --values keycloak/generated-values.yaml \
  --version 21.4.4 \
  --namespace iam \
  --create-namespace
```

**Apply the ingress configuration for Keycloak:**

```bash
kubectl -n iam apply -f keycloak/generated-ingress.yaml
```

**Custom Keycloak Image**

If you have a custom Keycloak image that includes the Keycloak-OPA adapter plugin, you can specify it in the `keycloak/values-template.yaml` file by uncommenting and modifying the `image` section:

```yaml
image:
  registry: your.registry
  repository: eoepca/keycloak-with-opa-plugin
  tag: your-tag
  pullPolicy: Always
```

Replace `your.registry`, `eoepca/keycloak-with-opa-plugin`, and `your-tag` with your registry, repository, and tag.

---

### 5. Create `eoepca` Keycloak realm

Keycloak establishes an initial `master` realm which should be reserved for global adminsitration only. It is best practice to create a dedicated realm for platform identity and protection of BB resources.

Thus, we create a dedicated `eoepca` realm.

**Obtain an Access Token for Administration**

Retrieve an access token using the admin credentials.

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
    "https://auth-apx.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" | jq -r '.access_token' \
)
```

**Create the `eoepca` Realm**

Creates a new realm named `eoepca`.

```bash
curl --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://auth-apx.${INGRESS_HOST}/admin/realms" <<EOF
{
  "realm": "eoepca",
  "enabled": true
}
EOF
```

---

### 6. Create `eoepca` user for testing

For convenience we create an `eoepca` (test) user to support usage examples in this guide where a user must be assumed.

```bash
curl --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/users" <<EOF
{
  "username": "eoepca",
  "enabled": true,
  "credentials": [{
    "type": "password",
    "value": "changeme",
    "temporary": false
  }]
}
EOF
```

Replace `"changeme"` with a secure password of your choice.

---

### 7. Integrate GitHub as External Identity Provider

This involves two main steps:

1. **Create a GitHub OAuth Application**
2. **Add GitHub as a Keycloak Identity Provider**

#### a. Create a GitHub OAuth Application

Navigate to the GitHub [Register a new OAuth application](https://github.com/settings/applications/new) page to create a new application with the following settings (replace `${INGRESS_HOST}` with your actual domain):

- **Application Name**: e.g., `EOEPCA`
- **Homepage URL**: `https://auth-apx.${INGRESS_HOST}/realms/eoepca`
- **Authorization Callback URL**: `https://auth-apx.${INGRESS_HOST}/realms/eoepca/broker/github/endpoint`

Generate a new client secret.

Make note of the **Client ID** and **Client Secret**; you will need them in the next step.

#### b. Add GitHub as a Keycloak Identity Provider

Obtain an access token for administration (if not already done):

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
    "https://auth-apx.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" | jq -r '.access_token' \
)
```

Set your GitHub OAuth application credentials:

```bash
export GITHUB_CLIENT_ID=<your-github-client-id>
export GITHUB_CLIENT_SECRET=<your-github-client-secret>
```

Create the GitHub identity provider:

```bash
curl --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/identity-provider/instances" <<EOF
{
  "alias": "github",
  "providerId": "github",
  "enabled": true,
  "config": {
    "clientId": "${GITHUB_CLIENT_ID}",
    "clientSecret": "${GITHUB_CLIENT_SECRET}",
    "redirectUri": "https://auth-apx.${INGRESS_HOST}/realms/eoepca/broker/github/login"
  }
}
EOF
```

#### c. Confirm Login via GitHub

Using a fresh browser session, navigate to the user account endpoint:

```text
https://auth-apx.<your-ingress-host>/realms/eoepca/account
```

On the **Sign-in** page, select **GitHub**, and follow the flow to authorize Keycloak to access your GitHub profile, completing the login process.

---

### 8. Deploy Open Policy Agent (OPA)

#### a. Create Keycloak Client for OPA

Before deploying OPA, you need to create a Keycloak client for it.

**Obtain Access Token for Administration**

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
    "https://auth-apx.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" | jq -r '.access_token' \
)
```

**Create the `opa` Client**

Create the `opa` client in Keycloak:

> You should have ${OPA_CLIENT_SECRET} from the `configure-iam.sh` script.
> Run `echo ${OPA_CLIENT_SECRET}` to ensure you have the secret set. 
> If not, rerun the `configure-iam.sh` script and source the state file.

```bash
curl --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" <<EOF
{
  "clientId": "opa",
  "name": "OPA",
  "description": "Open Policy Agent",
  "enabled": true,
  "protocol": "openid-connect",
  "rootUrl": "https://opa-apx.${INGRESS_HOST}",
  "baseUrl": "https://opa-apx.${INGRESS_HOST}",
  "redirectUris": ["https://opa-apx.${INGRESS_HOST}/*", "/*"],
  "webOrigins": ["/*"],
  "publicClient": false,
  "clientAuthenticatorType": "client-secret",
  "secret": "${OPA_CLIENT_SECRET}",
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

**Verify the `opa` Client**

You can confirm the creation of the `opa` client:

```bash
curl --silent --show-error \
  -X GET \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" \
  | jq '.[] | select(.clientId == "opa")'
```

---

#### b. Install OPA using Helm

```bash
helm repo add opal https://permitio.github.io/opal-helm-chart
helm repo update opal
helm upgrade -i opa opal/opal \
  --values opa/values.yaml \
  --version 0.0.28 \
  --namespace iam \
  --create-namespace
```

#### c. Apply ingress configuration for OPA

```bash
kubectl -n iam apply -f opa/generated-ingress.yaml
```

---

## Validation and Operation

**Automated Validation:**

Run the validation script to ensure the IAM components are deployed correctly.

```bash
bash validation.sh
```

**Further Validation:**

After deployment, the IAM exposes several endpoints for authentication, authorization, and administration. Replace `<INGRESS_HOST>` with your actual ingress host domain in the URLs below.

### Keycloak

**Keycloak Home Page:**

- URL: `https://auth-apx.<INGRESS_HOST>/`

**OpenID Connect Discovery Endpoint:**

- URL: `https://auth-apx.<INGRESS_HOST>/realms/eoepca/.well-known/openid-configuration`

**OAuth 2.0 Authorization Endpoint:**

- URL: `https://auth-apx.<INGRESS_HOST>/realms/eoepca/protocol/openid-connect/auth`

**OAuth 2.0 Token Endpoint:**

- URL: `https://auth-apx.<INGRESS_HOST>/realms/eoepca/protocol/openid-connect/token`

**Administration Console:**

- URL: `https://auth-apx.<INGRESS_HOST>/admin/`

**Accessing the Administration Console:**

1. **Retrieve Admin Credentials**
    
    The admin credentials are stored in the state file. Retrieve them using:
    
    ```bash
    source ~/.eoepca/state
    echo "Username: $KEYCLOAK_ADMIN_USER"
    echo "Password: $KEYCLOAK_ADMIN_PASSWORD"
    ```
    
2. **Login to the Console**
    
    Navigate to the Administration Console URL and log in with the retrieved credentials.
    

### Open Policy Agent (OPA)

**OPA Endpoint:**

- URL: `https://opa-apx.<INGRESS_HOST>/`

You can test policy evaluations by sending requests to OPA's REST API. For example:

```bash
curl -X POST "https://opa-apx.<INGRESS_HOST>/v1/data/example/allow" \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": "alice"}}'
```

---

### Validating Kubernetes Resources

Ensure that all Kubernetes resources are running correctly.

```bash
kubectl get pods -n iam
```

**Expected Output**:

- All pods should be in the `Running` state.
- No pods should be in `CrashLoopBackOff` or `Error` states.

---

## Creating a Keycloak Client

The following provides a general illustration of creating a client (`myclient`) via the Keycloak API.

### Obtain Access Token for Administration

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
    "https://auth-apx.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" | jq -r '.access_token' \
)
```

### Create the client

Creating a client with identifier `myclient`

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

### Verify the created client

You can confirm the creation of the `myclient` client:

```bash
curl --silent --show-error \
  -X GET \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" \
  | jq '.[] | select(.clientId == "myclient")'
```

### Delete client

Get the unique ID for the `myclient` client:

```bash
myclient_id=$( \
  curl --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
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

## Obtain Access Token (JWT) - Device Flow

The example client (`myclient`) was created with `OAuth 2.0 Device Authorization Grant` enabled. This is the recommended flow to obtain an access token - for example, from a Jupyter notebook that is accessing the BB service APIs.

### Step 1 - Initiate the Device Auth Flow

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
echo -e "\nNavigate to the following URL in your browser: ${verification_uri_complete}"
```

### Step 2 - Authorize via the provided URL

```bash
xdg-open "${verification_uri_complete}"
```

### Step 3 - Poll for token following user authorization

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

The access token can then be used as `Authorization: Bearer` in requests to the BB service APIs - assuming that the device flow was performed via the relevant client for target BB.

---

## Uninstalling the IAM Components

### Uninstall Keycloak

```bash
kubectl -n iam delete -f keycloak/generated-ingress.yaml
bash delete-secrets.sh
helm -n iam uninstall keycloak
```

### Uninstall OPA

```bash
kubectl -n iam delete -f opa/generated-ingress.yaml
helm -n iam uninstall opa
```

#### Delete the `opa` Keycloak Client

Obtain the access token:

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
    "https://auth-apx.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" | jq -r '.access_token' \
)
```

Get the unique ID for the `opa` client:

```bash
OPA_CLIENT_ID="$( \
  curl --silent --show-error \
    -X GET \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" \
    | jq -r '.[] | select(.clientId == "opa") | .id' \
)"
```

Delete the client:

```bash
curl --silent --show-error \
  -X DELETE \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients/${OPA_CLIENT_ID}"
```

---

## Further Reading

For more detailed information, refer to the following resources:

- [EOEPCA IAM Documentation](https://eoepca.readthedocs.io/projects/iam)
- [Keycloak Official Documentation](https://www.keycloak.org/documentation)
- [Open Policy Agent Documentation](https://www.openpolicyagent.org/docs/latest/)
- [OPAL (Open Policy Administration Layer) Documentation](https://github.com/permitio/opal)
