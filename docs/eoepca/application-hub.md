# Application Hub

The _Application Hub_ provides a set of web-based tooling, including JupyterLab for interactive analysis, Code Server for application development, and the capability to add user-defined interactive dashboards.

## Helm Chart

The _Application Hub_ is deployed via the `application-hub` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values, which are detailed in the [default values file for the chart](https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/values.yaml).

```bash
helm install --version 2.0.57 --values application-hub-values.yaml \
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
  clusterIssuer: letsencrypt-production

jupyterhub:
  fullnameOverride: "application-hub"
  hub:
    existingSecret: application-hub-secrets
    extraEnv: 
        JUPYTERHUB_ENV: "dev"
        JUPYTERHUB_SINGLE_USER_IMAGE: "eoepca/pde-container:1.0.3"
        OAUTH_CALLBACK_URL: https://applicationhub.192-168-49-2.nip.io/hub/oauth_callback
        OAUTH2_USERDATA_URL: https://keycloak.192-168-49-2.nip.io/oxauth/restv1/userinfo
        OAUTH2_TOKEN_URL: https://keycloak.192-168-49-2.nip.io/oxauth/restv1/token
        OAUTH2_AUTHORIZE_URL: https://keycloak.192-168-49-2.nip.io/oxauth/restv1/authorize
        OAUTH_LOGOUT_REDIRECT_URL: "https://applicationhub.192-168-49-2.nip.io"
        OAUTH2_USERNAME_KEY: "preferred_username"
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
      # name: eoepca/application-hub
      # tag: "1.2.0"
      pullPolicy: Always
      # pullSecrets: []

    db:
      pvc:
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

The Application Hub requires an OIDC client to be registered with the Identity Service (Keycloak) in order to enable user identity integration - ref. `OAUTH_CLIENT_ID` and `OAUTH_CLIENT_SECRET`.

This can be created with the `create-client` helper script, as descirbed in section [Client Registration](./resource-protection-keycloak.md#client-registration).

For example...

```bash
../bin/create-client \
  -a https://keycloak.192-168-49-2.nip.io \
  -i https://identity-api.192-168-49-2.nip.io \
  -r "master" \
  -u "admin" \
  -p "changeme" \
  -c "admin-cli" \
  --id=application-hub \
  --name="Application Hub OIDC Client" \
  --secret="changeme" \
  --description="Client to be used by Application Hub for OIDC integration"
```

Corresponding to this client, a secret `application-hub-secrets` must be created (ref. value `jupyterhub.hub.existingSecret: application-hub-secrets`)...

```bash
kubectl -n proc create secret generic application-hub-secrets \
  --from-literal=JUPYTERHUB_CRYPT_KEY="$(openssl rand -hex 32)" \
  --from-literal=OAUTH_CLIENT_ID="application-hub" \
  --from-literal=OAUTH_CLIENT_SECRET="changeme"
```

## Post-deployment Manual Steps

The deployment of the Application Hub has been designed, as far as possible, to automate the configuration. However, there remain some steps that must be performed manually after the scripted deployment has completed...

* [Configure Groups and Users](#groups-and-users)

### Groups and Users

The default helm chart has some built-in application launchers whose assignments to example users (eric and bob) assume the existence of some JupyterHub groups - which must be replicated to exploit this configuration.

* In a browser, navigate to the Application Hub - https://applicationhub.192-168-49-2.nip.io/
* Login as the user eric (or bob) for admin access
* Select the `Admin` menu (top of page)
* Add groups `group-1`, `group-2`, `group-3` to ApplicationHub, and add users `eric`, `bob` to these groups

This setup corresponds to the 'sample' configuration that is built=in to the help chart - see file [`config.yaml`](https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/files/hub/config.yml).

## Additional Information

Additional information regarding the _Application Hub_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/application-hub)
