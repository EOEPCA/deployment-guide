# Identity Service

The _Identity Service_ provides the platform _Authorization Server_ for authenticated user identity and request authorization.

_Identity Service_ is composed of:

- **Keycloak**<br>
  _IAM Authorization Service - supporting OpenID Connect (OIDC), etc._
- **Postgres DB**<br>
  _Relational database used by Keycloak for persistence_
- **Identity API**<br>
  Service that provided a convenience API to simplify IAM management interactions with Keycloak.<br>
  Provides endpoints to create clients and protect resources.<br>
  Uses a keycloak python client which sends requests to Keycloak API
- **Identity API Gatekeeper**<br>
  Instance of _Gatekeeper_ to 'protect' access requests to the Identity API service.<br>
  Gatekeeper is a reusable component that provides the _Policy Enforcement_ for requests to individual resource servers.<br>
  A Gatekeeper instance should be configured and deployed for each application that requires protection by access policies. 

## Helm Chart

The _Identity Service_ is deployed via the `identity-service` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values - the full set of available values can be tailored according the helm chart defaults, that can be found here...

* **`identity-service`**<br>
  [https://github.com/EOEPCA/helm-charts/blob/main/charts/identity-service/values.yaml](https://github.com/EOEPCA/helm-charts/blob/main/charts/identity-service/values.yaml)
* **`identity-keycloak`**<br>
  [https://github.com/EOEPCA/helm-charts/blob/main/charts/identity-service/charts/identity-keycloak/values.yaml](https://github.com/EOEPCA/helm-charts/blob/main/charts/identity-service/charts/identity-keycloak/values.yaml)
* **`identity-postgres`**<br>
  [https://github.com/EOEPCA/helm-charts/blob/main/charts/identity-service/charts/identity-postgres/values.yaml](https://github.com/EOEPCA/helm-charts/blob/main/charts/identity-service/charts/identity-postgres/values.yaml)
* **`identity-api`**<br>
  [https://github.com/EOEPCA/helm-charts/blob/main/charts/identity-service/charts/identity-api/values.yaml](https://github.com/EOEPCA/helm-charts/blob/main/charts/identity-service/charts/identity-api/values.yaml)

```bash
helm install --version 1.0.97 --values identity-service-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  identity-service identity-service
```

## Values

The deployment must be configured for you environment. Some significant configuration values are elaborated here…

### identity-keycloak

#### Secrets

Keycloak relies upon a secret `identity-keycloak` that provides...

* `KEYCLOAK_ADMIN_PASSWORD` - admin password for Keycloak
* `KC_DB_PASSWORD` - password for connecting with Postgres DB<br>
  This should match the `POSTGRES_PASSWORD` setting for `identity-postgres` (see below)

The secret can either be created directly within the cluster, or can be created by the helm chart via values...

```yaml
identity-keycloak:
  secrets:
    # Values for secret 'identity-keycloak'
    # Note - if ommitted, these can instead be set by creating the secret independently.
    kcDbPassword: "changeme"
    keycloakAdminPassword: "changeme"
```

#### Ingress

The details for ingress (reverse-proxy) to the Keycloak service - in particular the hostname and possible TLS - must be specified...

```yaml
identity-keycloak:
  ingress:
    enabled: true
    className: nginx
    annotations:
      ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      cert-manager.io/cluster-issuer: letsencrypt-production
    hosts:
      - host: keycloak.192-168-49-2.nip.io
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: identity-keycloak-tls
        hosts:
          - keycloak.192-168-49-2.nip.io
```

### identity-postgres

#### Secrets

Postgres relies upon a secret `identity-postgres` that provides...

* `POSTGRES_PASSWORD` - superuser password for PostgreSQL
* `PGPASSWORD` - password used for client connections to the DB

The secret can either be created directly within the cluster, or can be created by the helm chart via values...

```yaml
identity-postgres:
  secrets:
    # Values for secret 'identity-postgres'
    # Note - if ommitted, these can instead be set by creating the secret independently.
    postgresPassword: "changeme"
    pgPassword: "changeme"
```

#### Persistence

In order to persist data, Postgres requires a Persistent Volume Claim.

This can be specified as an existing volume claim - for example as described in the [Persistence](./persistence.md#pre-defined-persistent-volume-claims) section.

```yaml
identity-postgres:
  volumeClaim:
    name: eoepca-userman-pvc
```

### identity-api

#### Secrets

The Identity API relies upon a secret `identity-api` that provides...

* `ADMIN_PASSWORD`<br>
  Admin password for Keycloak<br>
  This should match the `KEYCLOAK_ADMIN_PASSWORD` setting for `identity-keycloak` (see above)

The secret can either be created directly within the cluster, or can be created by the helm chart via values...

```yaml
identity-api:
  secrets:
    # Values for secret 'identity-api'
    # Note - if ommitted, these can instead be set by creating the secret independently
    # e.g. as a SealedSecret via GitOps.
    adminPassword: "changeme"
```

!!! note
    It is also possible to set the value of `ADMIN_PASSWORD` directly as an [environment variable](#environment-variables).<br>
    In this case it is necessary to set the `secret` as optional...

    ```
    identity-api:
      secrets:
        optional: true
    ```

#### Environment Variables

The Identity API service can be configured via environment variables as follows...

* `AUTH_SERVER_URL`<br>
  URL of the Keycloak Authorization Server.
  Can also be set via value `configMap.authServerUrl`
* `ADMIN_USERNAME`<br>
  Admin user for Keycloak
* `REALM`<br>
  The Keycloak realm

```yaml
identity-api:
  deployment:
    # Config values that can be passed via env vars
    extraEnv:
      - name: AUTH_SERVER_URL  # see configMap.authServerUrl instead
        value: https://keycloak.192-168-49-2.nip.io
      - name: ADMIN_USERNAME
        value: admin
      - name: ADMIN_PASSWORD  # see secrets.adminPassword instead
        value: changeme
      - name: REALM
        value: master
```

### identity-api-gatekeeper

#### Secrets

gatekeeper relies upon a secret `identity-api-protection` that provides...

* `PROXY_CLIENT_SECRET`<br>
  Password for the Keycloak client configured for use by this Gatekeeper instance - corresponding to `config.client-id`.
* `PROXY_ENCRYPTION_KEY`<br>
  Encryption Key used by Gatekeeper.

The secret can either be created directly within the cluster, or can be created by the helm chart via values...

```yaml
identity-api-gatekeeper:
  secrets:
    # Values for secret 'identity-api-protection'
    # Note - if ommitted, these can instead be set by creating the secret independently.
    clientSecret: "changeme"
    encryptionKey: "changemechangeme"
```

#### Configuration

Configuration of Gatekeeper via the file `config.yaml` that is mounted into the deployment...

* `client-id`<br>
  ID of the Keycloak client to be used by this Gatekeeper instance.
* `discovery-url`<br>
  Discovery URL of the Keycloak Authorization Server
* `cookie-domain`<br>
  Domain in which this Gatekeeper instance creates cookies 

```yaml
identity-api-gatekeeper:
  config:
    client-id: identity-api
    discovery-url: https://keycloak.192-168-49-2.nip.io/realms/master
    cookie-domain: 192-168-49-2.nip.io
```

#### Ingress

The details for ingress (reverse-proxy) to the Gatekeeper service that protects the Identity API...

```
identity-api-gatekeeper:
  targetService:
    host: identity-api.192-168-49-2.nip.io
  ingress:
    annotations:
      ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      cert-manager.io/cluster-issuer: letsencrypt
```

## Identity API Client

The Identity API is protected via an instance of Gatekeeper - which relies upon a Keycloak client having been created for authorization decision/enforcement flows between Gatekeeper and Keycloak.

As described in the ['create-client' section below](#create-client-helper-script), this can be achieved using the `create-client` helper script.

!!! note
    At time of client creation, the Identity API is not yet protected with an ingress.<br>
    Therefore, we use a `port-forward` to interface directly with the Identity API service.

```bash
$ kubectl -n um port-forward svc/identity-api "9876":http >/dev/null &
$ portForwardPid=$!

$ ./deploy/bin/create-client \
  -a https://keycloak.192-168-49-2.nip.io \
  -i http://localhost:9876 \
  -r master \
  -u admin \
  -p changeme \
  -c admin-cli \
  --id=identity-api \
  --name="Identity API Gatekeeper" \
  --secret=changeme \
  --description="Client to be used by Identity API Gatekeeper" \
  --resource="admin" --uris='/*' --scopes=view --users="admin"

$ kill -TERM $portForwardPid
```

## `create-user` Helper Script

The Keycloak Admin UI can be used to create users interactively.

Alternatvely there is a helper script `create-user` that can be used.

The script is available in the [`deployment-guide` repository](https://github.com/EOEPCA/deployment-guide), and can be obtained as follows...

```bash
git clone git@github.com:EOEPCA/deployment-guide
cd deployment-guide
```

The `create-user` helper script requires some command-line arguments...

```bash
$ ./deploy/bin/create-user -h

Create a new user.
create-user -h | -a {auth_server} -r {realm} -c {client} -u {admin-username} -p {admin-password} -U {new-username} -P {new-password}

where:
    -h  show help message
    -a  authorization server url (default: http://keycloak.192-168-49-2.nip.io)
    -r  realm within Keycloak (default: master)
    -u  username used for authentication (default: admin)
    -p  password used for authentication (default: changeme)
    -c  client id of the bootstrap client used in the create request (default: admin-cli)
    -U  name of the (new) user to create
    -P  password for the (new) user to create
```

## Protection of Resources

The Identity Service is capable of protecting resources using OpenID-connect/SAML clients, resources (URIs/scopes), policies (user based, role based, etc) and permissions (associations between policies and resources).

Creating and protecting resources can be done in multiple ways, as described in the following sections.

#### Keycloak Admin UI

To create and protect resources using the keycloak User Interface (UI), do the following steps:

* (Optional) Create clients. Clients can be created using the keycloak user interface at http://keycloak.192-168-49-2.nip.io. You need to login as admin.<br>
  To create a client: Login as admin in the keycloak UI > Clients > Create Client > Set a name > Next > Turn Client Authentication and Authorization On > Add the valid redirect URI's > Save.
* (Optional) Create Users. Users > Add User. Then set a password for the user. Credentials > Set Password.
* Select a client.
* Create a Resource: Select Authorization tab > Resources > Create Resource.
* Create a Policy: In client details, select Authorization > Policies > Create Policy > Select Policy Type (e.g.: User) > Select users > Save.
* Create Authorization Scope: In client details, select Authorization > Scopes > Create authorization scope > Save.
* Create a Permission: In client details, select Authorization > Permissions > Create Permission > Create Resource Based Permission > Select Resources to protect > Select Policies > Save.


#### `create-client` Helper Script

Alternatively, a script was developed to allow simultaneaously create a client, create resources and protect them.

The script is available in the [`deployment-guide` repository](https://github.com/EOEPCA/deployment-guide), and can be obtained as follows...

```bash
git clone git@github.com:EOEPCA/deployment-guide
cd deployment-guide
```

The `create-client` helper script requires some command-line arguments...

```
$ ./deploy/bin/create-client -h

Add a client with protected resources.
create-client [-h] [-a] [-i] [-u] [-p] [-c] [-s] [-t | --token t] [-r] --id id [--name name] (--secret secret | --public) [--default] [--authenticated] [--resource name] [--uris u1,u2] [--scopes s1,s2] [--users u1,u2] [--roles r1,r2]

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
    --public              public client (no client secret)
    --default             add default resource - /* authenticated
    --authenticated       allow access to the resource only when authenticated
    --resource            resource name
    --uris                resource uris - separated by comma (,)
    --scopes              resource scopes - separated by comma (,)
    --users               user names with access to the resource - separated by comma (,)
    --roles               role names with access to the resource - separated by comma (,)
```

The script interacts with Identity API and therefore requires admin authorization.<br>
It accepts basic authentication with username and password with `-u` and `-p` parameters, respectively - or a bearer access token with `-t` parameter.

To generate the access token needed to use the script, you can get it through the login in the eoepca portal, by accessing the cookies in the browser.<br>
See section [EOEPCA Portal](../quickstart/scripted-deployment.md#eoepca-portal) for details regarding deployment/configuration of the [`eoepca-portal`](../quickstart/scripted-deployment.md#eoepca-portal).

Or you can generate an access token using postman oauth2.0, as described in the Postman document [Requesting an OAuth 2.0 token](https://learning.postman.com/docs/sending-requests/authorization/oauth-20/#requesting-an-oauth-20-token).

Script execution examples:

1. With username/password<br>
  ```bash
  ./deploy/bin/create-client \
    -a https://keycloak.192-168-49-2.nip.io \
    -i https://identity-api.192-168-49-2.nip.io \
    -r master \
    -u admin \
    -p changeme \
    -c admin-cli \
    --id=myservice-gatekeeper \
    --name="MyService Gatekeeper" \
    --secret=changeme \
    --description="Client to be used by MyService Gatekeeper" \
    --resource="Eric space" --uris=/eric/* --users=eric \
    --resource="Alice space" --uris=/alice/* --users=alice \
    --resource="Admin space" --uris=/admin/* --roles=admin
  ```

1. With access token<br>
  ```bash
  ./deploy/bin/create-client \
    -a https://keycloak.192-168-49-2.nip.io \
    -i https://identity-api.192-168-49-2.nip.io \
    -r master \
    -t eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJXZWFIY2pscThPc1RUYjdlV0s5SjJTTDFBUDIyazZpajdlMGFlVHRNU2xRIn0.eyJleHAiOjE3MDAyNDM4MzgsImlhdCI6MTcwMDI0Mzc3OCwiYXV0aF90aW1lIjoxNzAwMjQxODYyLCJqdGkiOiI2MWI0ZGRhYy1mOWZjLTRmZjktOWQ4Zi01NWU1N2NlNmE5ODgiLCJpc3MiOiJodHRwczovL2lkZW50aXR5LmtleWNsb2FrLmRldmVsb3AuZW9lcGNhLm9yZy9yZWFsbXMvbWFzdGVyIiwiYXVkIjpbImFkZXMtcmVhbG0iLCJkZW1vLXJlYWxtIiwiZHVtbXktc2VydmljZS1yZWFsbSIsIm1hc3Rlci1yZWFsbSIsImFjY291bnQiLCJlb2VwY2EtcmVhbG0iXSwic3ViIjoiZTNkZTMyNGUtMGY0NS00MWUwLTk2YTctNTM1YzkxMTA1NTUyIiwidHlwIjoiQmVhcmVyIiwiYXpwIjoiZW9lcGNhLXBvcnRhbCIsIm5vbmNlIjoiMTIwMGJlNzAtZWI1Ni00Nzc2LThjODgtOWRiOWQxMDdiMGY2Iiwic2Vzc2lvbl9zdGF0ZSI6ImVmNGUwOTlmLTFmMDgtNDY3MC04ZmE2LTJiOGI3OGUwNWMzMSIsImFjciI6IjAiLCJhbGxvd2VkLW9yaWdpbnMiOlsiKiJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsiY3JlYXRlLXJlYWxtIiwiZGVmYXVsdC1yb2xlcy1tYXN0ZXIiLCJvZmZsaW5lX2FjY2VzcyIsImFkbWluIiwidW1hX2F1dGhvcml6YXRpb24iLCJ1c2VyIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWRlcy1yZWFsbSI6eyJyb2xlcyI6WyJ2aWV3LWlkZW50aXR5LXByb3ZpZGVycyIsInZpZXctcmVhbG0iLCJtYW5hZ2UtaWRlbnRpdHktcHJvdmlkZXJzIiwiaW1wZXJzb25hdGlvbiIsImNyZWF0ZS1jbGllbnQiLCJtYW5hZ2UtdXNlcnMiLCJxdWVyeS1yZWFsbXMiLCJ2aWV3LWF1dGhvcml6YXRpb24iLCJxdWVyeS1jbGllbnRzIiwicXVlcnktdXNlcnMiLCJtYW5hZ2UtZXZlbnRzIiwibWFuYWdlLXJlYWxtIiwidmlldy1ldmVudHMiLCJ2aWV3LXVzZXJzIiwidmlldy1jbGllbnRzIiwibWFuYWdlLWF1dGhvcml6YXRpb24iLCJtYW5hZ2UtY2xpZW50cyIsInF1ZXJ5LWdyb3VwcyJdfSwiZGVtby1yZWFsbSI6eyJyb2xlcyI6WyJ2aWV3LXJlYWxtIiwidmlldy1pZGVudGl0eS1wcm92aWRlcnMiLCJtYW5hZ2UtaWRlbnRpdHktcHJvdmlkZXJzIiwiaW1wZXJzb25hdGlvbiIsImNyZWF0ZS1jbGllbnQiLCJtYW5hZ2UtdXNlcnMiLCJxdWVyeS1yZWFsbXMiLCJ2aWV3LWF1dGhvcml6YXRpb24iLCJxdWVyeS1jbGllbnRzIiwicXVlcnktdXNlcnMiLCJtYW5hZ2UtZXZlbnRzIiwibWFuYWdlLXJlYWxtIiwidmlldy1ldmVudHMiLCJ2aWV3LXVzZXJzIiwidmlldy1jbGllbnRzIiwibWFuYWdlLWF1dGhvcml6YXRpb24iLCJtYW5hZ2UtY2xpZW50cyIsInF1ZXJ5LWdyb3VwcyJdfSwiZHVtbXktc2VydmljZS1yZWFsbSI6eyJyb2xlcyI6WyJ2aWV3LXJlYWxtIiwidmlldy1pZGVudGl0eS1wcm92aWRlcnMiLCJtYW5hZ2UtaWRlbnRpdHktcHJvdmlkZXJzIiwiaW1wZXJzb25hdGlvbiIsImNyZWF0ZS1jbGllbnQiLCJtYW5hZ2UtdXNlcnMiLCJxdWVyeS1yZWFsbXMiLCJ2aWV3LWF1dGhvcml6YXRpb24iLCJxdWVyeS1jbGllbnRzIiwicXVlcnktdXNlcnMiLCJtYW5hZ2UtZXZlbnRzIiwibWFuYWdlLXJlYWxtIiwidmlldy1ldmVudHMiLCJ2aWV3LXVzZXJzIiwidmlldy1jbGllbnRzIiwibWFuYWdlLWF1dGhvcml6YXRpb24iLCJtYW5hZ2UtY2xpZW50cyIsInF1ZXJ5LWdyb3VwcyJdfSwibWFzdGVyLXJlYWxtIjp7InJvbGVzIjpbInZpZXctaWRlbnRpdHktcHJvdmlkZXJzIiwidmlldy1yZWFsbSIsIm1hbmFnZS1pZGVudGl0eS1wcm92aWRlcnMiLCJpbXBlcnNvbmF0aW9uIiwiY3JlYXRlLWNsaWVudCIsIm1hbmFnZS11c2VycyIsInF1ZXJ5LXJlYWxtcyIsInZpZXctYXV0aG9yaXphdGlvbiIsInF1ZXJ5LWNsaWVudHMiLCJxdWVyeS11c2VycyIsIm1hbmFnZS1ldmVudHMiLCJtYW5hZ2UtcmVhbG0iLCJ2aWV3LWV2ZW50cyIsInZpZXctdXNlcnMiLCJ2aWV3LWNsaWVudHMiLCJtYW5hZ2UtYXV0aG9yaXphdGlvbiIsIm1hbmFnZS1jbGllbnRzIiwicXVlcnktZ3JvdXBzIl19LCJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX0sImVvZXBjYS1yZWFsbSI6eyJyb2xlcyI6WyJ2aWV3LWlkZW50aXR5LXByb3ZpZGVycyIsInZpZXctcmVhbG0iLCJtYW5hZ2UtaWRlbnRpdHktcHJvdmlkZXJzIiwiaW1wZXJzb25hdGlvbiIsImNyZWF0ZS1jbGllbnQiLCJtYW5hZ2UtdXNlcnMiLCJxdWVyeS1yZWFsbXMiLCJ2aWV3LWF1dGhvcml6YXRpb24iLCJxdWVyeS1jbGllbnRzIiwicXVlcnktdXNlcnMiLCJtYW5hZ2UtZXZlbnRzIiwibWFuYWdlLXJlYWxtIiwidmlldy1ldmVudHMiLCJ2aWV3LXVzZXJzIiwidmlldy1jbGllbnRzIiwibWFuYWdlLWF1dGhvcml6YXRpb24iLCJtYW5hZ2UtY2xpZW50cyIsInF1ZXJ5LWdyb3VwcyJdfX0sInNjb3BlIjoib3BlbmlkIGVtYWlsIHByb2ZpbGUiLCJzaWQiOiJlZjRlMDk5Zi0xZjA4LTQ2NzAtOGZhNi0yYjhiNzhlMDVjMzEiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsInByZWZlcnJlZF91c2VybmFtZSI6ImFkbWluIn0.FK6DhVzpCRFmef2acD2Hmc149e1GTOCGz13dZA828crFbG8j4uhpkoNpiZqdyOPmDtMQ-OebNfjTAUaOt2sS1FmEIBgb9IddcpHKNJOquRjdzQNsX09bX8pFUq1haGwKh6_QmABNOBcT-kQNDSZO-aq7-8FoO9PYa0GWvBRcbcx0W_ngyb7xHglaZTElzcDPBcUTW6llVTTTFygn55smwdxTZ7-tEsMVGM5gNuHwJyLB51HI5KDWrwgUm1hqhhRzvcoutDEAB_HSEXGNNeF7fjP9Qx6q04b7fKOTtnIlXsu3oYW4va9y754llMSJ7w8U-y7yI6Tm2UdNMdYqju7hAA \
    -c admin-cli \
    --id=myservice-gatekeeper \
    --name="MyService Gatekeeper" \
    --secret=changeme \
    --description="Client to be used by MyService Gatekeeper" \
    --resource="Eric space" --uris=/eric/* --users=eric \
    --resource="Alice space" --uris=/alice/* --users=alice \
    --resource="Admin space" --uris=/admin/* --roles=admin
  ```

#### Using Identity API

Also, an API was developed to interact more easily with the Keycloak API, that allows client, resource, policies and permissions management.

The API documentation can be found in its [Swagger UI](https://identity-api.192-168-49-2.nip.io/docs) at the service endpoint - [https://identity-api.192-168-49-2.nip.io/docs](https://identity-api.192-168-49-2.nip.io/docs).

The Identity API is best used in combination with the [`eoepca-portal`](../quickstart/scripted-deployment.md#eoepca-portal) test aide, which can be used to establish a login sesssion in the browser to the benefit of the Identity API swagger UI.<br>
See section [EOEPCA Portal](../quickstart/scripted-deployment.md#eoepca-portal) for details regarding deployment/configuration of the [`eoepca-portal`](../quickstart/scripted-deployment.md#eoepca-portal).

## Token Lifespans

By default the Access Token Lifespan is 1 minute. With the current ADES (zoo-dru) implementation this presents a problem - since the `access_token` that is provided to the process execute request will (most likely) have expired by the time the ADES attempts to use the `access_token` in its call to the Workspace API to register the processing outputs. The lifespan of the token must outlive the duration of the processing execution - which we must assume can take a long time.

To avoid this potential problem, the [Keycloak Admin web console](https://keycloak.192-168-49-2.nip.io/admin/master/console/) can be used to increase this token lifespan.

Thus, the following settings are recommended to be updated following deployment...

* [SSO Session Settings](https://keycloak.192-168-49-2.nip.io/admin/master/console/#/master/realm-settings/sessions)<br>
  [/admin/master/console/#/master/realm-settings/sessions](https://keycloak.192-168-49-2.nip.io/admin/master/console/#/master/realm-settings/sessions)
  * SSO Session Idle: `1 day`
  * SSO Session Max: `1 day`
* [Tokens](https://keycloak.192-168-49-2.nip.io/admin/master/console/#/master/realm-settings/tokens)<br>
  [/admin/master/console/#/master/realm-settings/tokens](https://keycloak.192-168-49-2.nip.io/admin/master/console/#/master/realm-settings/tokens)
  * Access Token Lifespan: `1 day`

## Additional Information

Additional information regarding the _Identity Service_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/identity-service)
* [GitHub Repository](https://github.com/EOEPCA/um-identity-service)
