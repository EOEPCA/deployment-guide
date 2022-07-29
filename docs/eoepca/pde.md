# Processor Development Environment (PDE)

The _Processor Development Environment (PDE)_ provides a web-based application that allows the user to perform platform-hosted interactive analysis and application development.

## Helm Chart

The _Processor Development Environment_ is deployed via the `eoepca/jupyterhub` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is derived from the public chart `jupyterhub/k8s-hub` that is available on DockerHub - [https://hub.docker.com/r/jupyterhub/k8s-hub](https://hub.docker.com/r/jupyterhub/k8s-hub).

```bash
helm install --version 1.1.12 --values pde-values.yaml pde eoepca/jupyterhub
```

## Values

The `jupyterhub/k8s-hub` chart supports many values. Typically, values for the following attributes may be specified:

* The persistence storage-class to be used
* URLs for OAuth integration with the EOEPCA Login Service (OIDC Provider)
* Ingress configuration
* Certificate Issuer for TLS

**Example `pde-values.yaml`...**

```yaml
hub:
  db:
    pvc:
      storageClassName: standard
  extraEnv:
    OAUTH_CALLBACK_URL: "https://pde.192.168.49.123.nip.io/hub/oauth_callback"
    OAUTH2_USERDATA_URL: "https://auth.192.168.49.123.nip.io/oxauth/restv1/userinfo"
    OAUTH2_TOKEN_URL: "https://auth.192.168.49.123.nip.io/oxauth/restv1/token"
    OAUTH2_AUTHORIZE_URL: "https://auth.192.168.49.123.nip.io/oxauth/restv1/authorize"
    OAUTH_LOGOUT_REDIRECT_URL: "https://auth.192.168.49.123.nip.io/oxauth/restv1/end_session?post_logout_redirect_uri=https://pde.192.168.49.123.nip.io"
    STORAGE_CLASS: "standard"
ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
    - host: pde.192.168.49.123.nip.io
      paths:
        - path: /
  tls:
    - hosts:
        - pde.192.168.49.123.nip.io
      secretName: pde-tls
```


### JupyterHub Secret

The PDE relies upon a Kubernetes secret `jupyterhub-secrets` that provides confidential values, including the client credentials for the Login Service. The credentials of the client registered for resource protection (ref. [Client Registration](resource-protection.md#client-registration)) can be re-used from the local file `client.yaml` as follows...

```
kubectl -n pde create secret generic jupyterhub-secrets \
  --from-literal=JUPYTERHUB_CRYPT_KEY="$(openssl rand -hex 32)" \
  --from-literal=OAUTH_CLIENT_ID="$(cat client.yaml | grep client-id | cut -d\  -f2)" \
  --from-literal=OAUTH_CLIENT_SECRET="$(cat client.yaml | grep client-secret | cut -d\  -f2)"
```

## PDE Usage

The PDE is accessed at the endpoint `https://pde.<domain>/`, configured by your domain - e.g. [https://pde.192.168.49.123.nip.io/](https://pde.192.168.49.123.nip.io/).

## Additional Information

Additional information regarding the _Processor Development Environment_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/pde-jupyterhub)
* [GitHub Repository](https://github.com/EOEPCA/pde-container)
