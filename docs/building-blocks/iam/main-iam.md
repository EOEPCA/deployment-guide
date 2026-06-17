# Identity and Access Management (IAM) Deployment Guide

The IAM Building Block installs Keycloak, the Keycloak Operator, OPA, OPAL and the IAM chart configuration used by the EOEPCA 2.1 baseline.

`INGRESS_CLASS=apisix` is required. nginx is rejected by the scripts because the OIDC route plugin wiring is APISIX-specific.

## Prerequisites

| Component | Requirement |
| --- | --- |
| Kubernetes | Cluster access with `kubectl` |
| Helm | Helm 3.5 or newer |
| APISIX Ingress Controller | Installed and selected as `INGRESS_CLASS=apisix` |
| cert-manager | Required only when using generated HTTPS certificates |
| Crossplane | Installed |
| Crossplane Keycloak provider | CRDs such as `providerconfigs.keycloak.m.crossplane.io` and `clients.openidclient.keycloak.m.crossplane.io` installed |

Check the local prerequisites from the IAM script directory:

```bash
cd deployment-guide/scripts/iam
bash check-prerequisites.sh
```

## Configure

```bash
bash configure-iam.sh
```

The script writes the rendered Helm values to `generated-values.yaml` and stores shared settings in `~/.eoepca/state`.

Important variables:

- `INGRESS_CLASS`: must be `apisix`.
- `INGRESS_HOST`: base domain, for example `example.com`.
- `KEYCLOAK_HOST`: defaults to `auth.${INGRESS_HOST}`.
- `REALM`: defaults to `eoepca`.
- `KEYCLOAK_ADMIN_USER` and `KEYCLOAK_ADMIN_PASSWORD`: bootstrap admin credentials.
- `KEYCLOAK_POSTGRES_PASSWORD`: PostgreSQL password for Keycloak.
- `IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET`: secret for the `crossplane-keycloak-provider` Keycloak service account.
- `OPA_CLIENT_ID` and `OPA_CLIENT_SECRET`: OIDC client used by the APISIX OPA route.
- `KEYCLOAK_TEST_USER`, `KEYCLOAK_TEST_ADMIN`, `KEYCLOAK_TEST_PASSWORD`: initial example users imported with the realm.

The chart imports the realm during initial Keycloak startup. If the realm already exists, change users and clients through Keycloak or Crossplane rather than expecting Helm to re-import them.

## Apply Secrets

```bash
bash apply-secrets.sh
```

This creates the `iam` and `iam-management` namespaces and the Kubernetes secrets consumed by the 2.1 chart:

- `keycloak-admin`
- `postgresql`
- `keycloak-provider`
- `opa-route`
- `iam-keycloak`

## Install

Use the develop chart repository used by the current ArgoCD baseline:

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
helm repo update eoepca-dev

helm upgrade --install iam eoepca-dev/iam-bb \
  --version 2.1.0-dev10 \
  --namespace iam \
  --create-namespace \
  --values generated-values.yaml
```

If `configure-iam.sh` generated APISIX TLS resources, apply them after the Helm install:

```bash
if [ -s apisix-tls.yaml ]; then
  kubectl apply -f apisix-tls.yaml
fi
```

Wait for Keycloak and the IAM workloads:

```bash
kubectl wait -n iam --for=condition=Ready keycloak.k8s.keycloak.org/iam-keycloak-operator --timeout=10m
kubectl rollout status deployment/iam-keycloak-operator-operator -n iam --timeout=5m
kubectl rollout status statefulset/iam-postgresql -n iam --timeout=5m
kubectl rollout status deployment/iam-opa -n iam --timeout=5m
```

## Validate

```bash
bash validation.sh
```

Useful manual checks:

```bash
source ~/.eoepca/state
kubectl get all -n iam
kubectl get keycloak,keycloakrealmimport -n iam
kubectl get providerconfig.keycloak.m.crossplane.io -A
curl -k "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}/.well-known/openid-configuration"
```

The Keycloak admin console is available at:

```bash
source ~/.eoepca/state
echo "${HTTP_SCHEME}://${KEYCLOAK_HOST}/admin/"
echo "Username: ${KEYCLOAK_ADMIN_USER}"
echo "Password: ${KEYCLOAK_ADMIN_PASSWORD}"
```

## OPA Smoke Test

Authenticate as the example user:

```bash
source ~/.eoepca/state
ACCESS_TOKEN=$( \
  curl -k --silent --show-error \
    -X POST \
    -d "username=${KEYCLOAK_TEST_USER}" \
    --data-urlencode "password=${KEYCLOAK_TEST_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=${OPA_CLIENT_ID}" \
    -d "client_secret=${OPA_CLIENT_SECRET}" \
    "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" \
  | jq -r '.access_token' \
)
echo "${ACCESS_TOKEN:0:20}..."
```

Call OPA through APISIX. Use `/health` for the smoke test; querying `/v1/data/system/authz/allow` is expected to be rejected because that is OPA's own administrative authorisation policy.

This is expected to return `{}`

```bash
curl -k --silent --show-error \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${HTTP_SCHEME}://opa.${INGRESS_HOST}/health"
```

And now try this same command with an incorrect Bearer Token:

```bash
curl -k --silent --show-error \
  -H "Authorization: Bearer wrongbearer" \
  "${HTTP_SCHEME}://opa.${INGRESS_HOST}/health"
```


## Cleanup

```bash
helm uninstall iam -n iam
kubectl delete namespace iam iam-management
```

Delete retained PVCs only when you deliberately want to remove Keycloak data:

```bash
kubectl delete pvc -n iam -l app=iam-postgresql
```
