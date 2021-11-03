# Helm Repositories

## EOEPCA Helm Charts

The EOEPCA building-blocks are engineered as containers for deployment to a Kubernetes cluster. Each building block defines a _Helm Chart_ to facilitate its deployment.

The EOEPCA Helm Chart Repository is configured with `helm` as follows...
```bash
helm repo add eoepca https://eoepca.github.io/helm-charts/
```

## Third-party Helm Charts

In addition to the EOEPCA Helm Chart Repository, the following repositories are also relied upon, and should be configured...

### Cert Manager

```bash
helm repo add jetstack https://charts.jetstack.io
```

### Nginx Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

## Repo Update

Refresh the local repo cache, after `helm repo add`...

```bash
helm repo update
```
