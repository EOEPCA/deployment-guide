# Identity and Access Management (IAM) Deployment Guide

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

**Check Prerequisites:**

```bash
bash check-prerequisites.sh
```

If any checks fail, address them before proceeding.

---

## Overview of Deployment Steps

1. **Configure the IAM Environment**: Provide ingress host, storage classes, etc.
2. **Install APISIX Ingress (if not done already)**: Ensure APISIX is ready.
3. **Deploy Keycloak**: Set up the central identity provider.
4. **Create the `eoepca` Realm and Basic Users**: Keep `master` for admin tasks only.
5. **(Optional) Integrate External IdPs**: Add GitHub or other providers.
6. **Deploy OPA & OPAL**: For advanced policy decisions.
7. **Set up Policies & Permissions**: Restrict access to services as needed.
8. **Test & Validate**: Confirm that IAM is working as intended.

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
- **`STORAGE_CLASS`**: Kubernetes storage class for persistent volumes.
    - _Example_: `standard`

The script will also generate secure passwords for:

- **`KEYCLOAK_ADMIN_PASSWORD`**: Password for the Keycloak admin account.
- **`KEYCLOAK_POSTGRES_PASSWORD`**: Password for the Keycloak PostgreSQL database.

These credentials will be stored in a state file at `~/.eoepca/state`.

### 2. Ensure APISIX is Installed

If you haven’t installed APISIX yet, follow the [APISIX Ingress Controller Guide](https://apisix.apache.org/docs/apisix/installation-guide/).

### 3. Apply Secrets

```bash
bash apply-secrets.sh
```

This creates Kubernetes secrets from the credentials generated earlier.

### 4. Deploy Keycloak

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update bitnami
helm upgrade -i keycloak bitnami/keycloak \
  --values keycloak/generated-values.yaml \
  --version 21.4.4 \
  --namespace iam \
  --create-namespace
```

Apply Keycloak ingress:

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

### 5. Create the `eoepca` Realm and a Test User

Instead of using `master`, create a dedicated `eoepca` realm. 
For convenience we create an `eoepca` (test) user to support usage examples in this guide where a user must be assumed.

Run:

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



### 6. (Optional) Integrate External Identity Providers

If you wish to add GitHub or another IdP, see [Advanced Configuration](advanced-iam.md) for detailed instructions and examples.

### 7. Create the `opa` Client

Follow the steps in [Client Administration](client-management.md) to create the `opa` client in the `eoepca` realm. 

You will need to: 

- Update the `clientId` to `opa`.
- Update the `rootUrl` and `baseUrl` to `opa-apx.${INGRESS_HOST}`.
- Update the `secret` to `${OPA_CLIENT_SECRET}` which was generated in the `configure-iam.sh` script.


### 8. Deploy OPA & OPAL

```bash
helm repo add opal https://permitio.github.io/opal-helm-chart
helm repo update opal
helm upgrade -i opa opal/opal \
  --values opa/values.yaml \
  --version 0.0.28 \
  --namespace iam \
  --create-namespace
```

Apply OPA ingress:

```bash
kubectl -n iam apply -f opa/generated-ingress.yaml
```

### 9. Testing & Validation

```bash
bash validation.sh
```

Check all pods:

```bash
kubectl get pods -n iam
```

Ensure all components (Keycloak, OPA, etc.) are running and accessible.

---

## Further Configuration & Usage

For detailed steps on:

- Creating and managing Keycloak clients
- Integrating external IdPs
- Applying advanced resource protection (groups, roles, OPA policies)
- Using the device flow to obtain tokens in a script or notebook

Refer to the [Client Administration](client-management.md) and [Advanced Configuration](advanced-iam.md).


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

## Cleanup

To remove IAM components:

```bash
kubectl -n iam delete -f keycloak/generated-ingress.yaml
bash delete-secrets.sh
helm -n iam uninstall keycloak

kubectl -n iam delete -f opa/generated-ingress.yaml
helm -n iam uninstall opa
```

If you created custom clients or realms, remove them using the scripts in `scripts/` or the instructions in the appendices.

---

## Further Reading

- [EOEPCA IAM Documentation](https://eoepca.readthedocs.io/projects/iam)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Open Policy Agent Documentation](https://www.openpolicyagent.org/docs/latest/)
- [OPAL Documentation](https://github.com/permitio/opal)
