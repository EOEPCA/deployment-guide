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
| Crossplane Keycloak provider | CRDs such as `providerconfigs.keycloak.m.crossplane.io`, `clients.openidclient.keycloak.m.crossplane.io` and `users.user.keycloak.m.crossplane.io` installed |

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

You'll be asked for, in order:

- `INGRESS_HOST`: base domain, for example `example.com`.
- `PERSISTENT_STORAGECLASS`: storage class for Keycloak's PostgreSQL data. Note: the chart's bundled PostgreSQL `StatefulSet` does not set `storageClassName` on its PVC, so this value has no effect for IAM specifically — the PVC always uses the cluster's default storage class.
- `REALM`: the Keycloak realm name, defaults to `eoepca`.
- `CLUSTER_ISSUER`: cert-manager cluster issuer for TLS certificates (only asked if cert-manager issuance was enabled during first-time setup).
- `OPA_CLIENT_ID`: OIDC client used by the APISIX OPA route.
- `KEYCLOAK_TEST_USER`: example non-admin user, created separately via Crossplane once IAM is up (see [Provision the Test User](#provision-the-test-user) below).
- `KEYCLOAK_TEST_ADMIN`: example admin user imported with the realm.
- `KEYCLOAK_TEST_PASSWORD`: password shared by both example users.

The script also generates and stores `KEYCLOAK_ADMIN_PASSWORD`, `KEYCLOAK_POSTGRES_PASSWORD`, `IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET`, `OPA_CLIENT_SECRET` and `IAM_OPA_SESSION_SECRET` — these print at the end of the run so you can save them. `KEYCLOAK_HOST` defaults to `auth.${INGRESS_HOST}`.

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
- `eoepca-user` (in `iam-management`, consumed by the Crossplane User created in [Provision the Test User](#provision-the-test-user))

## Install

Use the develop chart repository used by the current ArgoCD baseline:

```bash
helm repo add eoepca-dev https://eoepca.github.io/helm-charts-dev
helm repo update eoepca-dev

helm upgrade --install iam eoepca-dev/iam-bb \
  --version 2.1.0-dev12 \
  --namespace iam \
  --create-namespace \
  --values generated-values.yaml
```

Apply the APISIX TLS configuration if it was generated:

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

Keycloak becoming `Ready` only means the server is up — the `${REALM}` realm is imported by a separate, one-off Job that the Keycloak Operator creates a few seconds *afterwards*. `kubectl wait` fails immediately with `NotFound` if the Job doesn't exist yet, so wait for it to appear before waiting on its completion:

```bash
until kubectl get job/eoepca-realm -n iam >/dev/null 2>&1; do
  echo "Waiting for the realm import job to be created..."
  sleep 5
done
kubectl wait -n iam --for=condition=complete job/eoepca-realm --timeout=5m
```

If this times out, check `kubectl logs -n iam job/eoepca-realm`

## Provision the Test User

The `${REALM}` realm import only creates the `KEYCLOAK_TEST_ADMIN` user. The plain `KEYCLOAK_TEST_USER` test user is created afterwards via Crossplane, the same way other Building Blocks manage their own Keycloak resources.

```bash
kubectl apply -f generated-eoepca-user.yaml
kubectl wait --for=condition=Ready user.user.keycloak.m.crossplane.io/eoepca-user -n iam-management --timeout=2m
```

## Validate

> **Prefer a notebook?** Run `../../notebooks/run.sh` and open the <a href="http://localhost:8888/lab/tree/iam/iam.ipynb" target="_blank">IAM notebook</a> at `http://localhost:8888`.

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

Authenticate as the example user, using the password grant against the confidential `OPA_CLIENT_ID` client (fine for a known test user here, but avoid this grant type for real user-facing clients):

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


## Uninstallation

Delete the Crossplane-managed user first, while Keycloak is still up, so its finalizer clears cleanly:

```bash
kubectl delete -f generated-eoepca-user.yaml --ignore-not-found

kubectl delete namespace iam-management
kubectl wait --for=delete namespace/iam-management --timeout=5m

helm uninstall iam -n iam
kubectl delete namespace iam
```

!!! warning
    Deleting `iam-management` removes every other Building Block's Keycloak clients, roles, and groups, not just IAM's own — expect any other deployed BB's SSO to break until IAM (and its clients) are reinstalled.

Delete retained PVCs only when you deliberately want to remove Keycloak data:

```bash
kubectl delete pvc -n iam data-iam-postgresql-0
```
