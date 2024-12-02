# IAM

## Clone Repo

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/iam
```

## En Vars

```bash
export INGRESS_HOST=endvrpad.rconway.uk
export STORAGE_CLASS=standard
export KEYCLOAK_ADMIN_USER=admin
export KEYCLOAK_ADMIN_PASSWORD=changeme
export KEYCLOAK_POSTGRES_PASSWORD=changeme

envsubst <keycloak/secrets/kustomization-template.yaml >keycloak/secrets/kustomization.yaml
envsubst <keycloak/values-template.yaml >keycloak/generated-values.yaml
envsubst <keycloak/ingress-template.yaml >keycloak/generated-ingress.yaml

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

### Uninstall

```bash
kubectl -n iam delete -f keycloak/generated-ingress.yaml
kubectl -n iam delete -k keycloak/secrets
helm -n iam uninstall keycloak
```

## Open Policy Agent (OPA)

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
kubectl -n iam apply -f opa/generated-ingress.yaml
```

### Uninstall

```bash
kubectl -n iam delete cm/opa-startup-data
kubectl -n iam delete -f opa/generated-ingress.yaml
helm -n iam uninstall opa
```

