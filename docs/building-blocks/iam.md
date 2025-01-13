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
| Kubernetes         | Cluster (tested on v1.28)              | [Installation Guide](../prerequisites/kubernetes.md)             |
| Helm               | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller   | Properly installed                     | [Installation Guide](../prerequisites/ingress-controller.md)  |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md) |

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

Refer to the [APISIX Ingress Controller Deployment Guide](../prerequisites/ingress-controller.md#apisix-ingress-controller) for detailed instructions.

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

## Apply Resource Protection

General instructions for applying protection for resources served by BB APIs.

This section provides an example resource protection using Keycloak groups and policies.

The example assumes protection for the `/healthcheck` endpoint within the `opa-client` service - protected via the group `mygroup` that emulates a team/project with common access.

The user `eoepca` is added to the `mygroup` group - assuming that the user was created as described in section [Create `eoepca` user for testing](#6-create-eoepca-user-for-testing).

The steps comprise:

* [**Create group**](#create-the-group)<br>
  The set of users who will be granted access to the resource - e.g. team/project.
* [**Add user to group**](#add-user-to-group)<br>
  User is granted access by group membership.
* [**Create policy**](#create-policy)<br>
  The policy identifies the groups that will be granted access.
* [**Create resource**](#create-resource)<br>
  The resource identifies the subject of the protection - identified via its endpoint `/eoepca`.
* [**Create permission**](#create-permission)<br>
  The permission connects the policy to the resource, and so establishes the protection.
* [**Create protected ingress**](#create-protected-ingress)<br>
  Public-facing URL that routes service access via the client that enforces authorisation.

### Obtain an Access Token for Administration

Note that the `ACCESS_TOKEN` is short-lived - so it becomes necessary to periodically repeat this call to refresh the access token.

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

### Create the `Group`

Create the group `mygroup`.

```bash
curl --silent --show-error \
  -X POST "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/groups" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json" \
  -d '
{
  "name": "mygroup"
}'
```

Retrieve the unique Group ID.

```bash
group_id=$( \
  curl --silent --show-error \
    -X GET "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/groups" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    | jq -r '.[] | select(.name == "mygroup") | .id' \
)
echo "Group ID: ${group_id}"
```

### Add user to group

Retrieve the unique User ID for user `eoepca`.

```bash
user_id=$(
  curl --silent --show-error \
    -X GET "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/users?username=eoepca" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    | jq -r '.[] | .id'
)
echo "User ID: ${user_id}"
```

Add user `eoepca` to group `team-eoepca`.

```bash
curl --silent --show-error \
  -X PUT "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/users/${user_id}/groups/${group_id}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json"
```

### Create policy

Create policy `mygroup-policy` that requires membership of the `mygroup` group. The policy is created in the `myclient` client.

Retrieve the unique Client ID.

```bash
client_id=$( \
  curl --silent --show-error \
    -X GET "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    | jq -r '.[] | select (.clientId == "myclient") | .id' \
)
echo "Client ID: ${client_id}"
```

Create the policy.

```bash
policy_id=$( \
  curl --silent --show-error \
    -X POST "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients/${client_id}/authz/resource-server/policy/group" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    -d @- <<EOF | jq -r '.id'
{
  "name": "mygroup-policy",
  "logic": "POSITIVE",
  "decisionStrategy": "UNANIMOUS",
  "groups": ["${group_id}"]
}
EOF
)
echo "Policy ID: ${policy_id}"
```

### Create resource

Create the resource `test-resource` for the `/healthcheck` endpoint within the `opa-client` service.

```bash
resource_id=$( \
  curl --silent --show-error \
    -X POST "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients/${client_id}/authz/resource-server/resource" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    -d @- <<EOF | jq -r '._id'
{
  "name": "test-resource",
  "uris": ["/healthcheck"],
  "ownerManagedAccess": true
}
EOF
)
echo "Resource ID: ${resource_id}"
```

### Create permission

Associate the policy `mygroup-policy` with the `test-resource` resource by creating a permission.

The effect of this is to allow access to anyone in the `mygroup` group to access the path `/healthcheck` within the `opa-client` service.

```bash
permission_id=$( \
  curl --silent --show-error \
    -X POST "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients/${client_id}/authz/resource-server/policy/resource" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    -d @- <<EOF | jq -r '.id'
{
  "name": "mygroup-access",
  "description": "Group mygroup access to /healthcheck",
  "logic": "POSITIVE",
  "decisionStrategy": "UNANIMOUS",
  "resources": ["${resource_id}"],
  "policies": ["${policy_id}"]
}
EOF
)
echo "Permission ID: ${permission_id}"
```

### Create Protected Ingress

Having established the protection policy in the Keycloak client `myclient` - the next step is to create an `ApisixRoute` that provides ingress to the `opa-service` endpoint exploiting `myclient` to apply the protection to incoming requests.

```bash
cat - <<EOF | kubectl -n iam apply -f -
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: myservice
spec:
  http:
    - name: test-resource
      match:
        hosts:
          - myservice-apx.$INGRESS_HOST
        paths:
          - /*
      backends:
        - serviceName: opa-opal-client
          servicePort: 7000
      plugins:
        # Require authorization for access
        # ...expects access token via header 'Authroization: Bearer <access-token>'
        - name: authz-keycloak
          enable: true
          config:
            client_id: myclient
            client_secret: changeme
            discovery: "https://auth-apx.$INGRESS_HOST/realms/eoepca/.well-known/uma2-configuration"
            lazy_load_paths: true
            ssl_verify: false
EOF
```

Note that, for convenience, the `client_id` and `client_secret` have been included directly in the `config`. Alternatively the `secretRef` field can be used to refrence a secret that contains the `client_id` and `client_secret`.

### Test Protected Ingress

Obtain an access token using the Device Flow to authenticate as user `eoepca`.

#### Initiate the Device Auth Flow

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

#### Authorize via the provided URL

Login as the `eoepca` user, that is a member of the `mygroup` group, and hence should receive access to the `/healthcheck` resource of the `opa-client` service.

```bash
xdg-open "${verification_uri_complete}"
```

#### Poll for token following user authorization

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

The access token can then be used as `Authorization: Bearer` in requests to the protected endpoint.

#### Request `/healthcheck` using the access token

```bash
curl myservice-apx.$INGRESS_HOST/healthcheck \
  -H "Authorization: Bearer ${access_token}" \
  -H "X-No-Force-Tls: true"
```

_**Access is allowed** with the status response - `{"status":"ok"}`._

_Note use of the header `X-No-Force-Tls` to avoid unwanted redirection to `https` (which is not configured for this test ingress)._

#### Denial of Access

##### Using a different user

Repeat the Device Flow to obtain an access token, but logging in as a different user - i.e. not in the `mygroup` group.

Then repeat the access attempt to `myservice-apx.$INGRESS_HOST/healthcheck` using the token.

_**Access is denied** with the response - `{"error":"access_denied","error_description":"not_authorized"}`._

Using the same 'unprivileged' access token - check that access to endpoints other then the protected `/healthcheck` are allowed.

```bash
curl myservice-apx.$INGRESS_HOST \
  -H "Authorization: Bearer ${access_token}" \
  -H "X-No-Force-Tls: true"
```

_**Access is allowed** with the status response - `{"status":"ok"}`._

##### Without access token

Repeat the request without the `access_token` to demonstrate denial.

```bash
curl myservice-apx.$INGRESS_HOST/healthcheck \
  -H "X-No-Force-Tls: true"
```

_**Access is denied** with the response - `{"message":"Missing JWT token in request"}`._

### ALTERNATIVE - Role-based Permission

The previous steps protect the `/healthcheck` zoo endpoint by directly referencing the `group` to which access is granted.

Alternatively, the permission could be expressed with an additional indirection via a `role`. In this case, access to the `/healthcheck` resource references a `role` rather than the `group`. The `mygroup` group can then be added to the role, and hence receive access.

In Keycloak, a role can be created either at the level of a realm, or scoped to a specific client - using the API endpoints...

* **realm** - `/admin/realms/eoepca/roles`
* **client** - `/admin/realms/eoepca/clients/{client-id}/roles`

See the [Keycloak Admin REST API](https://www.keycloak.org/docs-api/latest/rest-api/) for more details.

### ALTERNATIVE - OPA Policy

Another alternative is to define an OPA policy, instead of using Keycloak authorization configuration.

In this case the `ApisixRoute` would use the `opa` plugin instead of the `authz-keycloak` plugin to interface directly with OPA to assert the authorization policy.

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
