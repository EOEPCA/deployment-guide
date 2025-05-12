> **Note:** If the EOEPCA IAM Building Block is required during deployment, specific steps will be provided in the relevant sections of the building block deployment guide. This section serves as a reference and is applicable only if you're using the EOEPCA IAM Building Block. Ensure the EOEPCA IAM Building Block is installed. For more information, refer to [this guide](./main-iam.md).


This document covers advanced IAM configurations beyond the basic setup. Use these steps if you want to integrate external identity providers, protect resources with fine-grained policies, and leverage roles or OPA policies for authorisation.

---

## Resource Protection with Keycloak Policies



#### Scripted Approach

```bash
cd deployment-guide/scripts/utils
bash protect-resource.sh
```
        
When prompted:

- **Client ID**: `your-client-id` (the identifier for the client application you configured)
- **Resource Type**: `urn:your-client:resources:default` (a unique URI representing the type of resource)
- **Resource URI**: `/your-api-endpoint/*` (the path pattern for the protected resources)
- **Username**: e.g., `username` (the user account you want to test with; create one in Keycloak if necessary)


---

#### Manual Approach

If you choose to perform the steps manually, follow the instructions below.

1. **Create a Group** (e.g. `mygroup`).
2. **Add a User to the Group**.
3. **Create a Policy** that allows members of `mygroup`.
4. **Create a Resource** to represent the endpoint (`/healthcheck`).
5. **Create a Permission** to link the policy and resource, enforcing group-based access control.
6. **Configure Ingress** so APISIX + Keycloak enforce these policies.
7. **Test Access** using a Device Flow token.


**Obtain Access Token for Administration:**

```bash
source ~/.eoepca/state
ACCESS_TOKEN=$( \
  curl --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://auth.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" \
  | jq -r '.access_token' \
)
```

**Create the Group `mygroup`:**

```bash
curl --silent --show-error \
  -X POST "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/groups" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -d '{"name": "mygroup"}'
```

Retrieve the group ID:

```bash
group_id=$( \
  curl --silent --show-error \
    -X GET "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/groups" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  | jq -r '.[] | select(.name == "mygroup") | .id' \
)
echo "Group ID: ${group_id}"
```

**Add a User to the Group:**

Obtain the user's ID (e.g., the `eoepca` user created previously):

```bash
user_id=$( \
  curl --silent --show-error \
    -X GET "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/users?username=eoepcauser" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  | jq -r '.[0].id'
)
echo "User ID: ${user_id}"
```

Add the user to `mygroup`:

```bash
curl --silent --show-error \
  -X PUT "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/users/${user_id}/groups/${group_id}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}"
```

**Create a Policy (`mygroup-policy`):**

First, find the client ID for the client (e.g., `myclient` or another service client):

```bash
client_id=$( \
  curl --silent --show-error \
    -X GET "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/clients" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  | jq -r '.[] | select(.clientId == "myclient") | .id' \
)
```

Create the policy:

```bash
policy_id=$( \
  curl --silent --show-error \
    -X POST "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/clients/${client_id}/authz/resource-server/policy/group" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
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

**Create a Resource (`test-resource` for `/healthcheck`):**

Note that the `client_id` is the 'internal' unique identifier that is assigned by Keycloak - which can be retrieved as described above.

```bash
resource_id=$( \
  curl --silent --show-error \
    -X POST "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/clients/${client_id}/authz/resource-server/resource" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
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

**Create a Permission (`mygroup-access`):**

Link the resource and the policy.

The effect of this is to allow access to anyone in the `mygroup` group to access the path `/healthcheck` within the `opa-client` service.

```bash
permission_id=$( \
  curl --silent --show-error \
    -X POST "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/clients/${client_id}/authz/resource-server/policy/resource" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
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

**Create Protected Ingress (APISIX Route):**

Having established the protection policy in the Keycloak client `myclient` - the next step is to create an `ApisixRoute` that provides ingress to the `opa-service` endpoint exploiting `myclient` to apply the protection to incoming requests.

```bash
cat <<EOF | kubectl -n iam apply -f -
apiVersion: apisix.apache.org/v2
kind: ApisixRoute
metadata:
  name: myservice
spec:
  http:
    - name: test-resource
      match:
        hosts:
          - myservice.$INGRESS_HOST
        paths:
          - /*
      backends:
        - serviceName: opa-opal-client
          servicePort: 7000
      plugins:
        - name: authz-keycloak
          enable: true
          config:
            client_id: myclient
            client_secret: changeme
            discovery: "https://auth.$INGRESS_HOST/realms/${REALM}/.well-known/uma2-configuration"
            ssl_verify: false
EOF
```

Note that, for convenience, the `client_id` and `client_secret` have been included directly in the `config`. Alternatively the `secretRef` field can be used to refrence a secret that contains the `client_id` and `client_secret`.

**Test Access:**

Obtain a token using the device flow (see [client-management.md](client-management.md) for details), then access the protected endpoint:

```bash
curl myservice.$INGRESS_HOST/healthcheck \
  -H "Authorization: Bearer ${access_token}" \
  -H "X-No-Force-Tls: true"
```

Group members see `{"status":"ok"}`, others see `{"error":"access_denied","error_description":"not_authorized"}`.

---

## Role-Based vs Group-Based Permissions

The above example used a group. For more granular control or organisational alignment, you can use Keycloak roles. Instead of adding users directly to groups, you create roles and assign those roles to groups or users. Adjust the policy to reference roles instead of groups. The Keycloak Admin REST API is similar; you'd just target the `/roles` endpoints.

---

## OPA Policy Integration

Instead of relying solely on Keycloak's policy engine, you can use OPA policies for authorisation. Configure APISIX to query OPA for decisions:

- **OPA Plugin Setup**: Instead of `authz-keycloak`, use the `opa` plugin in the ApisixRoute.
- **OPA Policy Rego Files**: Store policies in a Git repository managed by OPAL.
- **Policy Enforcement**: APISIX queries OPA at runtime, and OPA returns allow/deny decisions based on Rego rules.

Refer to OPA documentation for writing Rego policies and OPAL docs for syncing policies from Git.



## Integrating GitHub as an External Identity Provider

Integrating GitHub as an external IdP allows your users to sign in with their GitHub accounts. You must first register an OAuth application with GitHub.

### 1. Create a GitHub OAuth Application

Go to the [GitHub OAuth Apps page](https://github.com/settings/applications/new) and register a new application:

- **Application Name**: e.g. `EOEPCA`
- **Homepage URL**: `https://auth.${INGRESS_HOST}/realms/${REALM}`
- **Authorization Callback URL**: `https://auth.${INGRESS_HOST}/realms/${REALM}/broker/github/endpoint`

Generate a Client Secret and note both the **Client ID** and **Client Secret**.

### 2. Add GitHub to Keycloak as an Identity Provider

Obtain an admin access token for Keycloak (replace `${INGRESS_HOST}` with your domain):

```bash
source ~/.eoepca/state
ACCESS_TOKEN=$( \
  curl --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_ADMIN_USER}" \
    --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://auth.${INGRESS_HOST}/realms/master/protocol/openid-connect/token" \
  | jq -r '.access_token' \
)
```

Set your GitHub OAuth credentials:

```bash
export GITHUB_CLIENT_ID=<your-github-client-id>
export GITHUB_CLIENT_SECRET=<your-github-client-secret>
```

Create the GitHub identity provider in the `eoepca` realm:

```bash
curl --silent --show-error \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @- \
  "https://auth.${INGRESS_HOST}/admin/realms/${REALM}/identity-provider/instances" <<EOF
{
  "alias": "github",
  "providerId": "github",
  "enabled": true,
  "config": {
    "clientId": "${GITHUB_CLIENT_ID}",
    "clientSecret": "${GITHUB_CLIENT_SECRET}",
    "redirectUri": "https://auth.${INGRESS_HOST}/realms/${REALM}/broker/github/endpoint"
  }
}
EOF
```

Now navigate to:

```bash
xdg-open https://auth.${INGRESS_HOST}/realms/${REALM}/account
```

Choose **GitHub** at the login prompt and complete the authorization flow.
