# Resource Protection (Gluu)

EOEPCA defines _Building Blocks_ within a micro-service architecture. The services are subject to protection within an _Identity and Access Management (IAM)_ approach that includes:

* Login Service (Authorization Server)
* Policy Decision Point (PDP)
* Policy Enforcement Point (PEP)

Building Blocks that act as a _Resource Server_ are individually protected by a Policy Enforcement Point (PEP). The PEP enforces the authorization decision in collaboration with the Login Service and Policy Decision Point (PDP).

The PEP expects to interface to a client (user agent, e.g. browser) using [_User Managed Access (UMA)_](https://docs.kantarainitiative.org/uma/wg/rec-oauth-uma-grant-2.0.html) flows. It is not typical for a client to support _UMA flows_, and so the PEP can be deployed with a companion _UMA User Agent_ component that interfaces between the client and the PEP, and performs the UMA Flow on behalf of the client.

**The _Resource Guard_ is a 'convenience' component that deploys the PEP & UMA User Agent as a cooperating pair.**

The Resource Guard 'inserts itself' into the request path of the target Resource Server using the `auth_request` facility offered by Nginx. Thus, the Resource Guard deploys with an Ingress specification that:

* Configures the `auth_request` module to defer access authorization to the `uma-user-agent` service
* Configures the ingress rules (host/path) for the target Resource Server

## Helm Chart

The _Resource Guard_ is deployed via the `resource-guard` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `resource-guard` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/resource-guard#readme).

It is expected to deploy multiple instances of the Resource Guard chart, one for each Resource Server to be protected.

```bash
helm install --version 1.3.1 --values myservice-guard-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  myservice-guard resource-guard
```

## Values

The helm chart is deployed with values that are passed through to the subcharts for the `pep-engine` and `uma-user-agent`. Typical values to be specified include:

* Host/domain details for the Login Service and PDP, e.g. `auth.192-168-49-2.nip.io`
* IP Address of the public facing reverse proxy (Nginx Ingress Controller), e.g. `192.168.49.2`
* Name of Persistent Volume Claim for `pep-engine` persistence, e.g. `myservice-pep-pvc`<br>
* TLS Certificate Provider, e.g. `letsencrypt-production`
* Optional specification of default resources with which to initialise the policy database for the component
* Ingress rules definition for reverse-proxy to the target Resource Server
* Name of `Secret` that contains the client credentials used by the `uma-user-agent` to interface with the Login Service.<br>
  _See [section Client Secret](#client-secret) below_

Example `myservice-guard-values.yaml`...
```yaml
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: myservice
  domain: 192-168-49-2.nip.io
  nginxIp: 192.168.49.2
  certManager:
    clusterIssuer: letsencrypt-production
#---------------------------------------------------------------------------
# PEP values
#---------------------------------------------------------------------------
pep-engine:
  configMap:
    asHostname: auth
    pdpHostname: auth
  customDefaultResources:
  - name: "Eric's space"
    description: "Protected Access for eric to his space in myservice"
    resource_uri: "/ericspace"
    scopes: []
    default_owner: "d3688daa-385d-45b0-8e04-2062e3e2cd86"
  volumeClaim:
    name: myservice-pep-pvc
    create: false
#---------------------------------------------------------------------------
# UMA User Agent values
#---------------------------------------------------------------------------
uma-user-agent:
  nginxIntegration:
    enabled: true
    hosts:
      - host: myservice
        paths:
          - path: /(.*)
            service:
              name: myservice
              port: 80
          - path: /(doc.*)
            service:
              name: myservice-docs
              port: 80
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/rewrite-target: /$1
  client:
    credentialsSecretName: "myservice-agent"
  logging:
    level: "debug"
  unauthorizedResponse: 'Bearer realm="https://portal.192-168-49-2.nip.io/oidc/authenticate/"'
#---------------------------------------------------------------------------
# END values
#---------------------------------------------------------------------------
```

## Client Credentials

The `uma-user-agent` requires _Client Credentials_ for its interactions with the `login-service`. The `uma-user-agent` expects to read these credentials from the file `client.yaml`, in the form...

```
client-id: <my-client-id>
client-secret: <my-secret>
```

### Client Registration

To obtain the _Client Credentials_ required by the `uma-user-agent` it is necessary to register a client with the `login-service`, or use the credentials for an existing client.

A [helper script](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.3/deploy/bin/register-client) is provided to register a basic client and obtain the required credentials. The script is available in the [`deployment-guide` repository](https://github.com/EOEPCA/deployment-guide), and can be obtained as follows...

```bash
git clone git@github.com:EOEPCA/deployment-guide
cd deployment-guide
```

The `register-client` helper script requires some command-line arguments...

```
Usage:
  register_client <authorization-server-hostname> <client-name> [<redirect-uri> [<logout-uri>]]
```

For example...

```bash
./deploy/bin/register-client auth.192-168-49-2.nip.io myclient

INFO: Preparing docker image... [done]
Client successfully registered.
Make a note of the credentials:
client-id: a98ba66e-e876-46e1-8619-5e130a38d1a4
client-secret: 73914cfc-c7dd-4b54-8807-ce17c3645558
```

Or to register OIDC redirect URLs...
```bash
./deploy/bin/register-client auth.192-168-49-2.nip.io myclient https://portal.192-168-49-2.nip.io/oidc/callback/ https://portal.192-168-49-2.nip.io/logout
```

The script writes the 'client credentials' to stdout - in the expected YAML configuration file format - which can be redirected to file...
```bash
./deploy/bin/register-client auth.192-168-49-2.nip.io myclient | tee client.yaml
```
...writes the client credentials to the file `client.yaml`.

**NOTE that the `register-client` helper relies upon [`docker`](https://docs.docker.com/engine/) to build and run the script.**

### Client Secret

The `client.yaml` configuration file is made available via a Kubernetes Secret...

```bash
kubectl -n myservice-ns create secret generic myservice-agent \
  --from-file=client.yaml \
  --dry-run=client -o yaml \
  > myservice-agent-secret.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myservice-agent
  namespace: myservice-ns
data:
  client.yaml: Y2xpZW50LWlkOiBhOThiYTY2ZS1lODc2LTQ2ZTEtODYxOS01ZTEzMGEzOGQxYTQKY2xpZW50LXNlY3JldDogNzM5MTRjZmMtYzdkZC00YjU0LTg4MDctY2UxN2MzNjQ1NTU4
```

The `resource-guard` deployment is configured with the name of the `Secret` through the helm chart value `client.credentialsSecretName`.

## User ID Token

As described in the [README for the Resource Guard](https://github.com/EOEPCA/helm-charts/tree/main/charts/resource-guard#readme), it is necessary for a request to a protected resource to provide the User ID Token in the request header.

### Obtaining the User ID Token

In the simple case of a user with username/password held within the Login Service, the User ID Token can be obtained as follows:

```
curl --location --request POST 'https://auth.192-168-49-2.nip.io/oxauth/restv1/token' \
--header 'Cache-Control: no-cache' \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode 'scope=openid user_name is_operator' \
--data-urlencode 'grant_type=password' \
--data-urlencode 'username=<username>' \
--data-urlencode 'password=<password>' \
--data-urlencode 'client_id=<client-id>' \
--data-urlencode 'client_secret=<client-password>'
```

The User ID Token is included in the `id_token` field of the json response.

Alternatively, OAuth/OIDC flows can be followed to authenticate via external identity providers.

### User ID Token in HTTP requests

The Resource Guard protection supports presentation of the User ID Token via the following HTTP request headers (in order of priority)...

* `Authorization` header as a bearer token - in the form: `Authorization: Bearer <token>`
* `X-User-Id` header
* `Cookie: auth_user_id=<token>`<br>
  > _Note that the name of the cookie is configurable_

## Additional Information

Additional information regarding the _Resource Guard_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/resource-guard)
* [README](https://github.com/EOEPCA/helm-charts/tree/main/charts/resource-guard#readme)
* GitHub Repository:
    * [pep-engine](https://github.com/EOEPCA/um-pep-engine)
    * [uma-user-agent](https://github.com/EOEPCA/uma-user-agent)
