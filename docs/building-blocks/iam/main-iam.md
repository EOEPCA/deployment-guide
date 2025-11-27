# Identity and Access Management (IAM) Deployment Guide

> Currently, **APISIX** Ingress Controller is the only supported ingress controller for the IAM Building Block. The deployment guide will be updated to support other ingress controllers in the future.

The EOEPCA Identity and Access Management (IAM) Building Block provides secure authentication and authorisation for all platform services. It enables you to manage users, roles, policies, and integrate with external identity providers.

**Key Features:**

- Central user management via Keycloak
- Fine-grained policy decisions using OPA & OPAL
- Integration with external IdPs (e.g., GitHub)
- Enforcement of policies at the APISIX ingress layer

---

## Prerequisites

| Component          | Requirement                            | Documentation Link                                                |
| ------------------ | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.32)              | [Installation Guide](../../prerequisites/kubernetes.md)             |
| Helm               | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |
| Ingress Controller   | Properly installed                     | [Installation Guide](../../prerequisites/ingress/overview.md)  |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../../prerequisites/tls.md) |

**Clone the Deployment Guide Repository:**

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/iam
```

**Check Prerequisites:**

```bash
bash check-prerequisites.sh
```

If any checks fail, address them before proceeding.

---

## Overview of Deployment Steps

1. **Configure the IAM Environment**: Provide ingress host, storage classes, etc.
2. **Deploy Keycloak**: Set up the central identity provider.
3. **Create the `eoepca` Realm and Basic Users**: Keep `master` for admin tasks only.
4. **(Optional) Integrate External IdPs**: Add GitHub or other providers.
5. **Deploy OPA & OPAL**: For advanced policy decisions.
6. **Set up Policies & Permissions**: Restrict access to services as needed.
7. **Test & Validate**: Confirm that IAM is working as intended.

For production, use proper TLS, stable storage, and consider external identity providers. For development, simpler self-signed certs and test credentials may suffice.

---

## Step-by-Step Deployment

### 1. Configure the IAM Deployment

```bash
bash configure-iam.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - _Example_: `example.com`
- **`PERSISTENT_STORAGECLASS`**: Kubernetes storage class for persistent volumes.
    - _Example_: `standard`
- **`CLUSTER_ISSUER`**: Issuer for TLS certificates
    - _Example_: `letsencrypt-http01-apisix`

The script will also generate secure passwords for:

- **`KEYCLOAK_ADMIN_PASSWORD`**: Password for the Keycloak admin account.
- **`KEYCLOAK_POSTGRES_PASSWORD`**: Password for the Keycloak PostgreSQL database.
- **`OPA_CLIENT_SECRET`**: Secret for the `opa` (Open Policy Agent) client in Keycloak

These credentials will be stored in a state file at `~/.eoepca/state`.

### 2. Apply Secrets

```bash
bash apply-secrets.sh
```

This creates Kubernetes secrets from the credentials generated earlier.

### 3. Deploy IAM Building Block
```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
helm repo update eoepca-dev
helm upgrade -i iam eoepca-dev/iam-bb \
  --version 2.0.0-rc2 \
  --namespace iam \
  --values generated-values.yaml \
  --create-namespace
```

Then apply the **APISIX TLS** resource:

```bash
kubectl apply -f apisix-tls.yaml
```

---

### 4. Establish Keycloak Management via Crossplane

Using the Crossplane Keycloak provider, we create a Keycloak client that allows Crossplane to manage Keycloak resources declaratively via CRDs. This is established via the following steps:

* Create a dedicated Keycloak client `iam-management` for Crossplane, with the necessary _Realm Management_ roles (`manage-users`, `manage-clients`, `manage-authorization`, `create-client`)
* Create the namespace `iam-management` for Crossplane Keycloak resources
* Establish Crossplane Keycloak provider configuration to connect to Keycloak using the `iam-management` client - serving resources in the `iam-management` namespace

> This provides the framework through which to manage the `eoepca` realm and its clients, by creation of Crossplane Keycloak resources in the `iam-management` namespace that will be satisfied by the Crossplane Keycloak provider.

#### 4.1. Keycloak Client for Crossplane Provider

Create a Keycloak client for the Crossplane Keycloak provider to allow it to interface with Keycloak. We create the client `iam-management`, which is used to perform administrative actions against the Keycloak API.

Use the `create-client.sh` script in the `/scripts/utils/` directory. This script prompts you for basic details and automatically creates a Keycloak client in your chosen realm.

```bash
bash ../utils/create-client.sh
```

When prompted:

> In many cases the default values (indicated `'-'`) are acceptable.

| Prompt | Description | `iam-management` |
|--------|-------------|------------------|
| Keycloak Admin Username and Password | Enter the credentials of your Keycloak admin user | - |
| Ingress Host | Platform base domain - e.g. `${INGRESS_HOST}` | - |
| Keycloak Host | e.g. `auth.${INGRESS_HOST}` | - |
| Realm | Typically `eoepca` | - |
| Confidential Client? | Specify `true` to create a CONFIDENTIAL client | `true` |
| Client ID | Identifier for the client in Keycloak | `iam-management` |
| Client Name | Display name for the client - for example... | `IAM Management` |
| Client Description | Descriptive text for the client - for example... | `Management of Keycloak resource via Crossplane` |
| Client secret | Enter the Client Secret that was generated during the configuration script (check `~/.eoepca/state`) | ref. env `IAM_MANAGEMENT_CLIENT_SECRET` |
| Subdomain | Redirect URL - Main service endpoint hostname as a prefix to `INGRESS_HOST` | `iam-management` |
| Additional Subdomains | Redirect URL - Additional `Subdomain` (prefix to `INGRESS_HOST`)<br>Comma-separated, or leave empty (e.g. `service-api`,`service-swagger`) | `<blank>` |
| Additional Hosts | Redirect URL - Additional full hostnames (i.e. outside of `INGRESS_HOST`)<br>Comma-separated, or leave empty (e.g. `service.some.platform`) | `<blank>` |

After it completes, you should see a JSON snippet confirming the newly created client.

The `iam-management` client requires specific `realm-management` roles to perform administrative actions against Keycloak.

Run the `crossplane-client-roles.sh` script in the `/scripts/utils/` directory, providing the `iam-management` client ID as an argument:

```bash
bash ../utils/crossplane-client-roles.sh iam-management
```

> The client is updated with the required roles.

#### 4.2. Create Crossplane Keycloak Provider Configuration

Now the Keycloak client is created, we can set up the Crossplane Keycloak provider configuration to connect to Keycloak using this client.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: iam-management
---
apiVersion: v1
kind: Secret
metadata:
  name: iam-management-client
  namespace: iam-management
stringData:
  credentials: |
    {
      "client_id": "$IAM_MANAGEMENT_CLIENT_ID",
      "client_secret": "$IAM_MANAGEMENT_CLIENT_SECRET",
      "url": "http://iam-keycloak.iam",
      "base_path": "",
      "realm": "$REALM"
    }
---
apiVersion: keycloak.m.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: provider-keycloak
  namespace: iam-management
spec:
  credentialsSecretRef:
    name: iam-management-client
    key: credentials
EOF
```

---

### 5. Create a Test User

> The `eoepca` realm should already be set up from the helm deployment. A test user is created with the username and password that was specified during IAM configuration. This user will be used for testing purposes throughout the deployment of other Building Blocks (BBs). You can configure the username and password as per your requirements (defaults to `eoepcauser`/`eoepcapassword`).

The user is created declaratively using the CRD defined by the Crossplane Keycloak provider. A `Secret` is used to inject the password securely.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${KEYCLOAK_TEST_USER}-password
  namespace: iam-management
stringData:
  password: ${KEYCLOAK_TEST_PASSWORD}
---
apiVersion: user.keycloak.m.crossplane.io/v1alpha1
kind: User
metadata:
  name: ${KEYCLOAK_TEST_USER}
  namespace: iam-management
spec:
  forProvider:
    realmId: eoepca
    username: ${KEYCLOAK_TEST_USER}
    email: ${KEYCLOAK_TEST_USER}@eoepca.org
    emailVerified: true
    firstName: Eoepca
    lastName: Testuser
    initialPassword:
      - temporary: false
        valueSecretRef:
          name: ${KEYCLOAK_TEST_USER}-password
          key: password
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

### 6. Create the Keycloak Client for OPA

A Keycloak client is required for the ingress protection of the OPA service. The client can be created using the Crossplane Keycloak provider via the `Client` CRD.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${OPA_CLIENT_ID}-keycloak-client
  namespace: iam-management
stringData:
  client_secret: ${OPA_CLIENT_SECRET}
---
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: ${OPA_CLIENT_ID}
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: ${OPA_CLIENT_ID}
    name: Open Policy Agent
    description: Open Policy Agent OIDC
    enabled: true
    accessType: CONFIDENTIAL
    rootUrl: ${HTTP_SCHEME}://opa.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://opa.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://opa.${INGRESS_HOST}
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
      name: ${OPA_CLIENT_ID}-keycloak-client
      key: client_secret
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

---

### 6. Testing & Validation

```bash
bash validation.sh
```

Check all pods:

```bash
kubectl get pods -n iam
```

Ensure all components (Keycloak, OPA, etc.) are running and accessible.

### 9. Test Suite Execution

Run the IAM tests from the system test suite.

> We only run the smoke tests here, since the full IAM tests rely upon the (example) protection of the Processing BB (OGC API Processes engine).

```bash
../../test-suite.sh -m smoketest test/iam
```

**_The test results are summarised to the file `test-report.xml`._**

If the Processing BB (example) protection has been applied, then the full IAM test suite can be run:

```bash
../../test-suite.sh test/iam
```

---

## Further Configuration & Usage

For detailed steps on:

- Creating and managing Keycloak clients
- Integrating external IdPs
- Applying advanced resource protection (groups, roles, OPA policies)
- Using the device flow to obtain tokens in a script or notebook

Refer to the [Client Administration](client-management.md) and [Advanced Configuration](advanced-iam.md).


After deployment, the IAM exposes several endpoints for authentication, authorization, and administration. Replace `${INGRESS_HOST}` with your actual ingress host domain in the URLs below.

### Keycloak

**Keycloak Home Page:**

- URL: `${HTTP_SCHEME}://auth.${INGRESS_HOST}/`

**OpenID Connect Discovery Endpoint:**

- URL: `${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}/.well-known/openid-configuration`

**OAuth 2.0 Authorization Endpoint:**

- URL: `${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/auth`

**OAuth 2.0 Token Endpoint:**

- URL: `${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/token`

**Administration Console:**

- URL: `${HTTP_SCHEME}://auth.${INGRESS_HOST}/admin/`

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

- URL: `${HTTP_SCHEME}://opa.${INGRESS_HOST}/`

You can test policy evaluations by sending requests to OPA's REST API.

Authenticate as test user `eoepcauser`...

```bash
source ~/.eoepca/state
# Authenticate as test user `eoepcauser`
ACCESS_TOKEN=$( \
  curl --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_TEST_USER}" \
    --data-urlencode "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=${OPA_CLIENT_ID}" \
    -d "client_secret=${OPA_CLIENT_SECRET}" \
    "${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}/protocol/openid-connect/token" | jq -r '.access_token' \
)
```

Simple `allow all` test query...

```bash
curl -X GET "${HTTP_SCHEME}://opa.${INGRESS_HOST}/v1/data/example/allow_all" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json"
```

User `bob` **is** a privileged user...

```bash
curl -X POST "${HTTP_SCHEME}://opa.${INGRESS_HOST}/v1/data/example/privileged_user" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"input": {"identity": {"attributes": { "preferred_username": ["bob"]}}}}'
```

User `larry` **is NOT** a privileged user...

```bash
curl -X POST "${HTTP_SCHEME}://opa.${INGRESS_HOST}/v1/data/example/privileged_user" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"input": {"identity": {"attributes": { "preferred_username": ["larry"]}}}}'
```

User `larry` **has** a verified email...

```bash
curl -X POST "${HTTP_SCHEME}://opa.${INGRESS_HOST}/v1/data/example/email_verified" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"input": {"identity": {"attributes": { "preferred_username": ["larry"], "email_verified": ["true"]}}}}'
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

## Cleanup

To remove IAM components:

```bash
helm -n iam uninstall iam
kubectl delete ns iam
```

If you created custom clients or realms, remove them using the scripts in `scripts/` or the instructions in the appendices.

---

## Further Reading

- [EOEPCA IAM Documentation](https://eoepca.readthedocs.io/projects/iam)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Open Policy Agent Documentation](https://www.openpolicyagent.org/docs/latest/)
- [OPAL Documentation](https://github.com/permitio/opal)
