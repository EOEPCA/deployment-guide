# Application Hub

The _Application Hub_ provides a set of web-based tooling, including JupyterLab for interactive analysis, Code Server for application development, and the capability to add user-defined interactive dashboards.

## Helm Chart

The _Application Hub_ is deployed via the `application-hub` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values, which are detailed in the [default values file for the chart](https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/values.yaml).

```bash
helm install --version 2.0.49 --values application-hub-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  application-hub application-hub
```

## Values

The Application Hub supports many values to configure the service - ref. the [default values file for the chart](https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/values.yaml).

Typically, values for the following attributes may be specified:

* The fully-qualified public URL for the service
* Specification of Ingress for reverse-proxy access to the service
* Storage class for persistence
* Node selector rule - required by JupyterHub to spawn container workloads
* Values for integration with the user workspace
* Integration of JupyterHub with the Login Service (identity provider) via OpenID Connect configuration
* OIDC client credentials from a secret

**Example `application-hub-values.yaml`...**

```yaml
ingress:
  enabled: true
  annotations: {}
  hosts:
    - host: applicationhub.192-168-49-2.nip.io
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: applicationhub-tls
      hosts:
      - applicationhub.192-168-49-2.nip.io
  clusterIssuer: "${TLS_CLUSTER_ISSUER}"

jupyterhub:
  ingress:
    enabled: true
  fullnameOverride: "application-hub"
  hub:
    existingSecret: application-hub-secrets
    extraEnv: 
        JUPYTERHUB_ENV: "dev"
        JUPYTERHUB_SINGLE_USER_IMAGE: "eoepca/pde-container:1.0.3"
        OAUTH_CALLBACK_URL: https://applicationhub.192-168-49-2.nip.io/hub/oauth_callback
        OAUTH2_USERDATA_URL: https://auth.192-168-49-2.nip.io/oxauth/restv1/userinfo
        OAUTH2_TOKEN_URL: https://auth.192-168-49-2.nip.io/oxauth/restv1/token
        OAUTH2_AUTHORIZE_URL: https://auth.192-168-49-2.nip.io/oxauth/restv1/authorize
        OAUTH_LOGOUT_REDIRECT_URL: "https://applicationhub.192-168-49-2.nip.io"
        OAUTH2_USERNAME_KEY: "user_name"
        STORAGE_CLASS: "standard"
        RESOURCE_MANAGER_WORKSPACE_PREFIX: "ws"

        JUPYTERHUB_CRYPT_KEY:
          valueFrom:
            secretKeyRef:
              name: application-hub-secrets
              key: JUPYTERHUB_CRYPT_KEY

        OAUTH_CLIENT_ID:
          valueFrom:
            secretKeyRef:
              name: application-hub-secrets
              key: OAUTH_CLIENT_ID
          
        OAUTH_CLIENT_SECRET:
          valueFrom:
            secretKeyRef:
              name: application-hub-secrets
              key: OAUTH_CLIENT_SECRET

    image:
      name: eoepca/application-hub
      tag: "1.0.0"
      pullPolicy: Always
      pullSecrets: []

    db:
      type: sqlite-pvc
      upgrade:
      pvc:
        annotations: {}
        selector: {}
        accessModes:
          - ReadWriteOnce
        storage: 1Gi
        subPath:
        storageClassName: standard
  
  singleuser:
    image:
      name: jupyter/minimal-notebook
      tag: "2343e33dec46"
    profileList: 
    - display_name:  "Minimal environment"
      description: "To avoid too much bells and whistles: Python."
      default: "True"
    - display_name:  "EOEPCA profile"
      description: "Sample profile"
      kubespawner_override:
        cpu_limit": 4
        mem_limit": "8G"

nodeSelector:
  key: minikube.k8s.io/primary
  value: \"true\"
```


## Client and Credentials

The Application Hub requires an OIDC client to registered with the Login Service in order to enable user identity integration. The client can be created via the login service web interface - e.g. [https://auth.192-168-49-2.nip.io](https://auth.192-168-49-2.nip.io).

In addition there is a helper script that can be used to create a basic client and obtain the credentials - using an approach that it similar to that described for [Resource Protection](resource-protection-gluu.md#client-registration)...
```bash
./deploy/bin/register-client auth.192-168-49-2.nip.io "Application Hub" | tee client-apphub.yaml
```

This command creates the client and outputs the credentials (to file and stdout), which must then be applied in a Kubernetes secret that is expected by the Application Hub deployment...

```bash
kubectl -n proc create secret generic application-hub-secrets \
  --from-literal=JUPYTERHUB_CRYPT_KEY="$(openssl rand -hex 32)" \
  --from-literal=OAUTH_CLIENT_ID="$(cat client-apphub.yaml | grep client-id | cut -d\  -f2)" \
  --from-literal=OAUTH_CLIENT_SECRET="$(cat client-apphub.yaml | grep client-secret | cut -d\  -f2)"
```

For example...

```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: application-hub-secrets
  namespace: proc
data:
  JUPYTERHUB_CRYPT_KEY: YjA4OGEyZGU3Mzg4ZWQxNmM1Zjg2Njc0YTA5MzlhNzI5YTY5NzU1NDJhYjYwZTllNWU2ZTZhYTQ5ZTc5ZDM5Zg==
  OAUTH_CLIENT_ID: Y2NhNDNmM2ItODQyZC00NzNmLTk3Y2YtYWUxOTNkZWJhOWMx
  OAUTH_CLIENT_SECRET: ZWFkYjk5NDQtOTRkYS00MTU3LTg1ZDgtNWJhMmJmODg5ZjE2
```

## Post-deployment Manual Steps

The deployment of the Application Hub has been designed, as far as possible, to automate the configuration. However, there remain some steps that must be performed manually after the scripted deployment has completed...

* [Configure OIDC Client](#oidc-client)
* [Configure Groups and Users](#groups-and-users)

### OIDC Client

The client that is created by the script `./deploy/bin/register-client` (as per above) needs to be manually adjusted using the Web UI of the Login Service...

* In a browser, navigate to the Login Service (Gluu) - https://auth.192-168-49-2.nip.io/ - and login as the `admin` user
* Open `OpenID Connect -> Clients` and search for the client created earlier - `Application Hub`
* Fix the setting `Authentication method for the Token Endpoint`  for the `ApplicationHub` - `client_secret_post` -> `client_secret_basic`
* Save the update

### Groups and Users

The default helm chart has some built-in application launchers whose assignments to example users (eric and bob) assume the existence of some JupyterHub groups - which must be replicated to exploit this configuration.

* In a browser, navigate to the Application Hub - https://applicationhub.192-168-49-2.nip.io/
* Login as the user eric (or bob) for admin access
* Select the `Admin` menu (top of page)
* Add groups `group-1`, `group-2`, `group-3` to ApplicationHub, and add users `eric`, `bob` to these groups

## Additional Information

Additional information regarding the _Application Hub_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/application-hub)
