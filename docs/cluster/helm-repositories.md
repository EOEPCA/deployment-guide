# Helm Repositories

!!! note
    This section identifies some helm chart repositories that can be referenced (for convenience) via `helm add`.<br>
    Nevertheless, all helm commands included in the guide specifically reference the source helm repository via the `--repo` argument to the `helm install` command - and thus it is not specifically necessary to `add` these repositories in advance.

## EOEPCA Helm Charts

The EOEPCA building-blocks are engineered as containers for deployment to a Kubernetes cluster. Each building block defines a _Helm Chart_ to facilitate its deployment.

The EOEPCA Helm Chart Repository is configured with `helm` as follows...
```bash
helm repo add eoepca https://eoepca.github.io/helm-charts/
```

## Third-party Helm Charts

In addition to the EOEPCA Helm Chart Repository, a variety of third party helm repositories are relied upon, as identified below.

### Cert Manager

```bash
helm repo add jetstack https://charts.jetstack.io
```

### Nginx Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

### Minio

```bash
helm repo add minio https://charts.min.io/
```

### Sealed Secrets (Bitnami)

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
```

### Harbor

```bash
helm repo add harbor https://helm.goharbor.io
```

## Repo Update

Refresh the local repo cache, after `helm repo add`...

```bash
helm repo update
```
