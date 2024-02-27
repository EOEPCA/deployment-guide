# Resource Protection (Keycloak)

EOEPCA defines _Building Blocks_ within a micro-service architecture. The services are subject to protection within an _Identity and Access Management (IAM)_ approach that includes:

* Keycloak - Identity Service (Authorization Server)
* Gatekeeper - Policy Enforcement

Building Blocks that act as a _Resource Server_ are individually protected by a dedicated Gatekeeper instance that enforces the authorization decision in collaboration with the Identity Service (Keycloak).

Gatekeeper 'inserts itself' into the request path of the target Resource Server using the `auth_request` facility offered by Nginx. Thus, Gatekeeper deploys with an Ingress specification that:

* Configures the `auth_request` module to defer access authorization to the `gatekeeper` service
* Configures the ingress rules (host/path) for the target Resource Server

## Helm Chart

Each _Gatekeeper_ is deployed via the `identity-gatekeeper` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values - the full set of available values can be seen at [https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/values.yaml](https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/values.yaml).

It is expected to deploy multiple instances of the `Gatekeeper` chart, one for each Resource Server to be protected.

```bash
helm install --version 1.0.10 --values myservice-gatekeeper-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  myservice-protection identity-gatekeeper
```

## Values

The helm chart is deployed with values that customise the service for the specific needs of the resource-server under protection and the deployment target platform.<br>
Typical values to be specified include:

* Host/domain details for the Keycloak Identity Service, e.g. `keycloak.192-168-49-2.nip.io`
* Credentials for the Keycloak client to be used by Gatekeeper (ideally via secret)
* TLS Certificate Provider, e.g. `letsencrypt-production`
* Ingress rules definition for reverse-proxy to the target Resource Server

Example `myservice-protection-values.yaml`...
```yaml
nameOverride: myservice-protection
config:
  client-id: myservice
  discovery-url: https://keycloak.192-168-49-2.nip.io/realms/master
  cookie-domain: 192-168-49-2.nip.io
targetService:
  host: myservice.192-168-49-2.nip.io
  name: myservice
  port:
    number: 80
secrets:
  # Values for secret 'myservice-protection'
  # Note - if ommitted, these can instead be set by creating the secret independently.
  clientSecret: "changeme"
  encryptionKey: "changemechangeme"
ingress:
  enabled: true
  className: nginx
  annotations:
    ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-production
  serverSnippets:
    custom: |-
      # Open access to some endpoints, including Swagger UI
      location ~ ^/(docs|openapi.json|probe) {
        proxy_pass {{ include "identity-gatekeeper.targetUrl" . }}$request_uri;
      }
```

## Client Credentials

Gatekeeper requires _Client Credentials_ for its interactions with the Keycloak `identity-service`. These credentials must be supplied by the secret named `<myservice>-protection`. The secret can be created directly by the helm chart - via the values `secrets.clientSecret` and `secrets.encryptionKey` - or perhaps more securely the secret can be created independently (e.g. via a `SealedSecret`).

## Client Registration

The Keycloak client can be created directly in the Keycloak admin console - e.g. via https://keycloak.192-168-49-2.nip.io/admin.

As an aide there is a helper script [`create-client`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/bin/create-client). The script is available in the [`deployment-guide` repository](https://github.com/EOEPCA/deployment-guide), and can be obtained as follows...

```bash
git clone git@github.com:EOEPCA/deployment-guide
cd deployment-guide
```

The `create-client` helper script requires some command-line arguments...

```
$ ./deploy/bin/create-client -h

Add a client with protected resources.
create-client [-h] [-a] [-i] [-u] [-p] [-c] [-s] [-t | --token t] [-r] --id id [--name name] --secret secret [--default] [--authenticated] [--resource name] [--uris u1,u2] [--scopes s1,s2] [--users u1,u2] [--roles r1,r2]

where:
    -h                    show help message
    -a                    authorization server url - e.g. https://keycloak.192-168-49-2.nip.io
    -i                    identity-api server url - e.g. https://identity-api.192-168-49-2.nip.io
    -u                    username used for authentication
    -p                    password used for authentication
    -c                    client id (of the bootstrap client used in the create request)
    -s                    client secret (of the bootstrap client used in the create request)
    -t or --token         access token used for authentication
    -r                    realm
    --id                  client id (of the created client)
    --name                client name (of the created client)
    --secret              client secret (of the created client)
    --default             add default resource - /* authenticated
    --authenticated       allow access to the resource only when authenticated
    --resource            resource name
    --uris                resource uris - separated by comma (,)
    --scopes              resource scopes - separated by comma (,)
    --users               user names with access to the resource - separated by comma (,)
    --roles               role names with access to the resource - separated by comma (,)
```

For example...

```bash
./deploy/bin/create-client \
  -a https://keycloak.192-168-49-2.nip.io \
  -i https://identity-api-protected.192-168-49-2.nip.io \
  -r "master" \
  -u "admin" \
  -p "changeme" \
  -c "admin-cli" \
  --id=myservice \
  --name="Gatekeeper for myservice" \
  --secret="changeme" \
  --description="Client to be used by Gatekeeper for myservice" \
  --resource="eric" --uris='/eric/*' --scopes=view --users="eric" \
  --resource="bob" --uris='/bob/*' --scopes=view --users="bob" \
  --resource="alice" --uris='/alice/*' --scopes=view --users="alice"
```

## User Tokens

Requests to resource server endpoints that are protected by Gatekeeper must carry an Access Token that has been obtained on behalf of the requesting user. The `access_token` is carried in the request header...

```http
Authorization: Bearer <access_token>
```

The Access Token for a given user  can be obtained with a call to the token endpoint of the Keycloak Identity Service - supplying the credentials for the user and the pre-registered client...

```bash
curl -L -X POST 'https://keycloak.192-168-49-2.nip.io/realms/master/protocol/openid-connect/token' \
  -H 'Cache-Control: no-cache' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'scope=openid profile email' \
  --data-urlencode 'grant_type=password' \
  --data-urlencode 'username=<username>' \
  --data-urlencode 'password=<password>' \
  --data-urlencode 'client_id=admin-cli'
```

A json response is returned, in which the field `access_token` provides the Access Token for the specified `<username>`.

## Additional Information

Additional information regarding the _Gatekeeper_ can be found at:

* [Container Image](https://quay.io/repository/gogatekeeper/gatekeeper)
* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/identity-gatekeeper)
* [GitHub Repository](https://github.com/gogatekeeper/gatekeeper)
