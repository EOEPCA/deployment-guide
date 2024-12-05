# IAM

## Clone Repo

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/iam
```

## En Vars

```bash
source ~/.eoepca/state
# TODO - should come from eoepca state...
# export KEYCLOAK_ADMIN_USER=admin
# export KEYCLOAK_ADMIN_PASSWORD=changeme
# export KEYCLOAK_POSTGRES_PASSWORD=changeme
# export OPA_CLIENT_SECRET=changeme

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
# TODO - should come from eoepca state...
# export KEYCLOAK_ADMIN_USER=admin
# export KEYCLOAK_ADMIN_PASSWORD=changeme
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

This comprises to two parts...

1. Creation of GitHub OAuth client
2. Add GitHub as Kewycloak Identity Provider

#### Create GitHub OAuth client

Navigate to the GitHub [Register a new OAuth app](https://github.com/settings/applications/new) page to create a new client with the following settings (replacing the value for `${INGRESS_HOST}`)...

* **_Application name_**: e.g. `eoepca` (something meaningful to you)
* **_Homepage URL_**: `https://auth-apx.${INGRESS_HOST}/realms/eoepca`
* **_Authorization callback URL_**: `https://auth-apx.${INGRESS_HOST}/realms/eoepca/broker/github/endpoint`

Select to `Generate a new client secret`.

Make note of the **_Client ID_** and **_Client Secret_** which are needed to configure the Identity Provider in Keycloak.

#### Add GitHub as a Keycloak Identity Provider

Integration of GitHub as a Keycloak Identity Provider can be achieved via the Keycloak API using the following steps.

Get access token...

```bash
source ~/.eoepca/state
# TODO - should come from eoepca state...
# export KEYCLOAK_ADMIN_USER=admin
# export KEYCLOAK_ADMIN_PASSWORD=changeme
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

Create the GitHub identity provider...

```bash
source ~/.eoepca/state
# TODO - should come from eoepca state...
# export GITHUB_CLIENT_ID=<tbd>
# export GITHUB_CLIENT_SECRET=<tbd>
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
# TODO - should come from eoepca state...
# export KEYCLOAK_ADMIN_USER=admin
# export KEYCLOAK_ADMIN_PASSWORD=changeme
# export OPA_CLIENT_SECRET=changeme
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
# TODO - should come from eoepca state...
# export KEYCLOAK_ADMIN_USER=admin
# export KEYCLOAK_ADMIN_PASSWORD=changeme
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
