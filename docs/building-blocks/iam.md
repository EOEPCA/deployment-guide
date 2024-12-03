# IAM

## Clone Repo

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/iam
```

## En Vars

```bash
source ~/.eoepca/state
export KEYCLOAK_ADMIN_USER=admin  # TODO - should come from eoepca state
export KEYCLOAK_ADMIN_PASSWORD=changeme  # TODO - should come from eoepca state
export OPA_CLIENT_SECRET=changeme  # TODO - should come from eoepca state

envsubst <keycloak/secrets/kustomization-template.yaml >keycloak/secrets/kustomization.yaml
envsubst <keycloak/values-template.yaml >keycloak/generated-values.yaml
envsubst <keycloak/ingress-template.yaml >keycloak/generated-ingress.yaml

envsubst <opa/secrets/kustomization-template.yaml >opa/secrets/kustomization.yaml
envsubst <opa/ingress-template.yaml >opa/generated-ingress.yaml
```

## Keycloak

### Helm Chart

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami && \
helm repo update bitnami && \
helm upgrade -i keycloak bitnami/keycloak \
  --values keycloak/generated-values.yaml \
  --version 21.4.4 \
  --namespace iam \
  --create-namespace
```

### Secret for Postgres

```bash
kubectl -n iam apply -k keycloak/secrets
```

### Ingress

```bash
kubectl -n iam apply -f keycloak/generated-ingress.yaml
```

### Post-deployment Configuration

#### Get access token for administration

```bash
source ~/.eoepca/state
export KEYCLOAK_ADMIN_USER=admin  # TODO - should come from eoepca state
export KEYCLOAK_ADMIN_PASSWORD=changeme  # TODO - should come from eoepca state
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

#### Create `eoepca` realm

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

#### (optional) Create a dedicated `eoepca` user for the new realm

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

### Integrate GitHub as External IdP

#### Create GitHub client

To create a GitHub client for Keycloak to use for integration, follow the steps in the [GitHub Configuration](https://eoepca.readthedocs.io/projects/iam/en/latest/admin/configuration/github-idp/github-setup-idp/#github-configuration) section of the IAM documentation.

Make note of the **client ID** and **client Secret**.

#### Configure Keycloak

To configure Keycloak integration with GitHub, using the above client credentials, follow the steps in the [Keycloak Configuration](https://eoepca.readthedocs.io/projects/iam/en/latest/admin/configuration/github-idp/github-setup-idp/#keycloak-configuration) section of the IAM documentation.

#### Confirm Login via GitHub IdP

Using a fresh browser session navigate to the user Account endpoint - `https://auth-apx.$INGRESS_HOST/realms/eoepca/account`.

On the `Sign-in` page select GitHub, and follow the flow to authorise Keycloak to access your GitHub profile, and so complete login.

### Uninstall

```bash
kubectl -n iam delete -f keycloak/generated-ingress.yaml
kubectl -n iam delete -k keycloak/secrets
helm -n iam uninstall keycloak
```

## Open Policy Agent (OPA)

### Create Keycloak client for OPA

#### Get access token for administration

```bash
source ~/.eoepca/state
export KEYCLOAK_ADMIN_USER=admin  # TODO - should come from eoepca state
export KEYCLOAK_ADMIN_PASSWORD=changeme  # TODO - should come from eoepca state
export OPA_CLIENT_SECRET=changeme  # TODO - should come from eoepca state
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

#### Create the `opa` client

```bash
# curl --silent --show-error \
curl  \
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
  "serviceAccountsEnabled": true,
  "authorizationServicesEnabled": true,
  "frontchannelLogout": true
}
EOF
```

#### Check details of new `opa` client

```bash
curl --silent --show-error \
  -X GET \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients" \
  | jq '.[] | select(.clientId == "opa")'
```

### Helm Chart

```bash
helm repo add opal https://permitio.github.io/opal-helm-chart && \
helm repo update opal && \
helm upgrade -i opa opal/opal \
  --values opa/values.yaml \
  --version 0.0.28 \
  --namespace iam \
  --create-namespace
```

### Ingress

```bash
kubectl -n iam apply -k opa/secrets
kubectl -n iam apply -f opa/generated-ingress.yaml
```

### Uninstall

```bash
kubectl -n iam delete cm/opa-startup-data
kubectl -n iam delete -f opa/generated-ingress.yaml
kubectl -n iam delete -k opa/secrets
helm -n iam uninstall opa
```

#### Delete the `opa` Keycloak client

Get the access token...

```bash
source ~/.eoepca/state
export KEYCLOAK_ADMIN_USER=admin  # TODO - should come from eoepca state
export KEYCLOAK_ADMIN_PASSWORD=changeme  # TODO - should come from eoepca state
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

Get the unique ID for the `opa` client...

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

Delete the client...

```bash
curl --silent --show-error \
  -X DELETE \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://auth-apx.${INGRESS_HOST}/admin/realms/eoepca/clients/${OPA_CLIENT_ID}"
```

