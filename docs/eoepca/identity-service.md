# Identity Service

The _Identity Service_ provides the platform _Authorization Server_ for authenticated user identity and request authorization.

_Identity Service_ is composed of:
- **Keycloak** - IAM solution which Identity Service relies on.
- **Postgres DB** - Database to store Keycloak's data.
- **Identity API** - API with endpoints to create clients and protect resources for applications using that client. Uses a keycloak python client which sends requests to Keycloak API.
- **Identity API Gatekeeper** - Authorization proxy used to enforce authorization access policies to the Identity API. A gatekeeper should be configured and launched for each application that wishes to be protected by access policies. 

## Helm Chart

The _Identity Service_ is deployed via the `identity-service` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `identity-service` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/identity-service#readme).

```bash
helm install --version 1.0.47 --values identity-service-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  identity-service identity-service
```

## Values

Example `identity-service-values.yaml`...
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: um-identity-service
  namespace: um
  annotations:
    meta.helm.sh/release-name: um-identity-service
    meta.helm.sh/release-namespace: um
spec:
  chart:
    spec:
      chart: identity-service
      version: 1.0.0
      sourceRef:
        kind: HelmRepository
        name: eoepca
        namespace: common
  values:
    volumeClaim:
      name: eoepca-userman-pvc
      create: false
    identity-keycloak:
      ingress:
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt
        hosts:
          - host: identity.keycloak.192-168-49-2.nip.io
            paths:
              - path: /
                pathType: Prefix
        tls:
          - secretName: identity-keycloak-tls-certificate
            hosts:
              - identity.keycloak.192-168-49-2.nip.io
    identity-postgres:
      volumeClaim:
        name: eoepca-userman-pvc
    identity-api:
      ingress:
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt
        hosts:
          - host: identity.api.192-168-49-2.nip.io
            paths:
              - path: /
                pathType: Prefix
        tls:
          - secretName: identity-api-tls-certificate
            hosts:
              - identity.api.192-168-49-2.nip.io
    identity-gateekeper:
      ingress:
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt
        hosts:
          - host: identity.gatekeeper.192-168-49-2.nip.io
            paths:
              - path: /
                pathType: Prefix
        tls:
          - secretName: identity-gatekeeper-tls-certificate
            hosts:
              - identity.gatekeeper.192-168-49-2.nip.io
  timeout: 5m0s
  interval: 1m0s
  secretName: login-service-tls
```

## Post-deployment Steps

Identity service is capable of protecting resources using OpenID-connect/SAML clients, resources (URIs/scopes), policies (user based, role based, etc) and permissions (associations between policies and resources).
Creating and protecting resources can be done in multiple ways, as we will see next.

#### Using Admin UI

To create and protect resources using the keycloak User Interface (UI), do the following steps:

* (Optional) Create clients. Clients can be created using the keycloak user interface at identity.keycloak.${environment}.eoepca.org. You need to login as admin.
  To create a client: Login as admin in the keycloak UI > Clients > Create Client > Set a name > Next > Turn Client Authentication and Authorization On > Add the valid redirect URI's > Save.
* (Optional) Create Users. Users > Add User. Then set a password for the user. Credentials > Set Password.
* Select a client.
* Create a Resource: Select Authorization tab > Resources > Create Resource.
* Create a Policy: In client details, select Authorization > Policies > Create Policy > Select Policy Type (e.g.: User) > Select users > Save.
* Create Authorization Scope: In client details, select Authorization > Scopes > Create authorization scope > Save.
* Create a Permission: In client details, select Authorization > Permissions > Create Permission > Create Resource Based Permission > Select Resources to protect > Select Policies > Save.


#### Using Bash script

Alternatively, a script was developed to allow simultaneaously create a client, create resources and protect them. The script can be found in https://github.com/EOEPCA/um-identity-service/tree/master/scripts.  
The script interacts with Identity API and therefore requires admin authorization.
It accepts basic authentication with username and password with -u and -p, respectively. Or a bearer access token with -t. To generate the access token needed to use the script, you can get it through the login in the eoepca portal, by accessing the cookies in the browser. Or you can generate an access token using postman oauth2.0, as described in: https://learning.postman.com/docs/sending-requests/authorization/oauth-20/#requesting-an-oauth-20-token.

Script execution examples:
1. With username/password
```bash
sh create-client.sh \
-e production \
-u admin
-p password
--id=api-gateekeper \
--name="Identity API Gatekeeper" \
--description="Client to be used by Identity API Gatekeeper" \
--resource="Eric space" --uris=/eric/* --users=eric \
--resource="Alice space" --uris=/alice/* --users=alice \
--resource="Admin space" --uris=/admin/* --roles=admin
```
2. With access token
```bash
sh create-client.sh \
-e production \
-t eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJXZWFIY2pscThPc1RUYjdlV0s5SjJTTDFBUDIyazZpajdlMGFlVHRNU2xRIn0.eyJleHAiOjE3MDAyNDM4MzgsImlhdCI6MTcwMDI0Mzc3OCwiYXV0aF90aW1lIjoxNzAwMjQxODYyLCJqdGkiOiI2MWI0ZGRhYy1mOWZjLTRmZjktOWQ4Zi01NWU1N2NlNmE5ODgiLCJpc3MiOiJodHRwczovL2lkZW50aXR5LmtleWNsb2FrLmRldmVsb3AuZW9lcGNhLm9yZy9yZWFsbXMvbWFzdGVyIiwiYXVkIjpbImFkZXMtcmVhbG0iLCJkZW1vLXJlYWxtIiwiZHVtbXktc2VydmljZS1yZWFsbSIsIm1hc3Rlci1yZWFsbSIsImFjY291bnQiLCJlb2VwY2EtcmVhbG0iXSwic3ViIjoiZTNkZTMyNGUtMGY0NS00MWUwLTk2YTctNTM1YzkxMTA1NTUyIiwidHlwIjoiQmVhcmVyIiwiYXpwIjoiZW9lcGNhLXBvcnRhbCIsIm5vbmNlIjoiMTIwMGJlNzAtZWI1Ni00Nzc2LThjODgtOWRiOWQxMDdiMGY2Iiwic2Vzc2lvbl9zdGF0ZSI6ImVmNGUwOTlmLTFmMDgtNDY3MC04ZmE2LTJiOGI3OGUwNWMzMSIsImFjciI6IjAiLCJhbGxvd2VkLW9yaWdpbnMiOlsiKiJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsiY3JlYXRlLXJlYWxtIiwiZGVmYXVsdC1yb2xlcy1tYXN0ZXIiLCJvZmZsaW5lX2FjY2VzcyIsImFkbWluIiwidW1hX2F1dGhvcml6YXRpb24iLCJ1c2VyIl19LCJyZXNvdXJjZV9hY2Nlc3MiOnsiYWRlcy1yZWFsbSI6eyJyb2xlcyI6WyJ2aWV3LWlkZW50aXR5LXByb3ZpZGVycyIsInZpZXctcmVhbG0iLCJtYW5hZ2UtaWRlbnRpdHktcHJvdmlkZXJzIiwiaW1wZXJzb25hdGlvbiIsImNyZWF0ZS1jbGllbnQiLCJtYW5hZ2UtdXNlcnMiLCJxdWVyeS1yZWFsbXMiLCJ2aWV3LWF1dGhvcml6YXRpb24iLCJxdWVyeS1jbGllbnRzIiwicXVlcnktdXNlcnMiLCJtYW5hZ2UtZXZlbnRzIiwibWFuYWdlLXJlYWxtIiwidmlldy1ldmVudHMiLCJ2aWV3LXVzZXJzIiwidmlldy1jbGllbnRzIiwibWFuYWdlLWF1dGhvcml6YXRpb24iLCJtYW5hZ2UtY2xpZW50cyIsInF1ZXJ5LWdyb3VwcyJdfSwiZGVtby1yZWFsbSI6eyJyb2xlcyI6WyJ2aWV3LXJlYWxtIiwidmlldy1pZGVudGl0eS1wcm92aWRlcnMiLCJtYW5hZ2UtaWRlbnRpdHktcHJvdmlkZXJzIiwiaW1wZXJzb25hdGlvbiIsImNyZWF0ZS1jbGllbnQiLCJtYW5hZ2UtdXNlcnMiLCJxdWVyeS1yZWFsbXMiLCJ2aWV3LWF1dGhvcml6YXRpb24iLCJxdWVyeS1jbGllbnRzIiwicXVlcnktdXNlcnMiLCJtYW5hZ2UtZXZlbnRzIiwibWFuYWdlLXJlYWxtIiwidmlldy1ldmVudHMiLCJ2aWV3LXVzZXJzIiwidmlldy1jbGllbnRzIiwibWFuYWdlLWF1dGhvcml6YXRpb24iLCJtYW5hZ2UtY2xpZW50cyIsInF1ZXJ5LWdyb3VwcyJdfSwiZHVtbXktc2VydmljZS1yZWFsbSI6eyJyb2xlcyI6WyJ2aWV3LXJlYWxtIiwidmlldy1pZGVudGl0eS1wcm92aWRlcnMiLCJtYW5hZ2UtaWRlbnRpdHktcHJvdmlkZXJzIiwiaW1wZXJzb25hdGlvbiIsImNyZWF0ZS1jbGllbnQiLCJtYW5hZ2UtdXNlcnMiLCJxdWVyeS1yZWFsbXMiLCJ2aWV3LWF1dGhvcml6YXRpb24iLCJxdWVyeS1jbGllbnRzIiwicXVlcnktdXNlcnMiLCJtYW5hZ2UtZXZlbnRzIiwibWFuYWdlLXJlYWxtIiwidmlldy1ldmVudHMiLCJ2aWV3LXVzZXJzIiwidmlldy1jbGllbnRzIiwibWFuYWdlLWF1dGhvcml6YXRpb24iLCJtYW5hZ2UtY2xpZW50cyIsInF1ZXJ5LWdyb3VwcyJdfSwibWFzdGVyLXJlYWxtIjp7InJvbGVzIjpbInZpZXctaWRlbnRpdHktcHJvdmlkZXJzIiwidmlldy1yZWFsbSIsIm1hbmFnZS1pZGVudGl0eS1wcm92aWRlcnMiLCJpbXBlcnNvbmF0aW9uIiwiY3JlYXRlLWNsaWVudCIsIm1hbmFnZS11c2VycyIsInF1ZXJ5LXJlYWxtcyIsInZpZXctYXV0aG9yaXphdGlvbiIsInF1ZXJ5LWNsaWVudHMiLCJxdWVyeS11c2VycyIsIm1hbmFnZS1ldmVudHMiLCJtYW5hZ2UtcmVhbG0iLCJ2aWV3LWV2ZW50cyIsInZpZXctdXNlcnMiLCJ2aWV3LWNsaWVudHMiLCJtYW5hZ2UtYXV0aG9yaXphdGlvbiIsIm1hbmFnZS1jbGllbnRzIiwicXVlcnktZ3JvdXBzIl19LCJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX0sImVvZXBjYS1yZWFsbSI6eyJyb2xlcyI6WyJ2aWV3LWlkZW50aXR5LXByb3ZpZGVycyIsInZpZXctcmVhbG0iLCJtYW5hZ2UtaWRlbnRpdHktcHJvdmlkZXJzIiwiaW1wZXJzb25hdGlvbiIsImNyZWF0ZS1jbGllbnQiLCJtYW5hZ2UtdXNlcnMiLCJxdWVyeS1yZWFsbXMiLCJ2aWV3LWF1dGhvcml6YXRpb24iLCJxdWVyeS1jbGllbnRzIiwicXVlcnktdXNlcnMiLCJtYW5hZ2UtZXZlbnRzIiwibWFuYWdlLXJlYWxtIiwidmlldy1ldmVudHMiLCJ2aWV3LXVzZXJzIiwidmlldy1jbGllbnRzIiwibWFuYWdlLWF1dGhvcml6YXRpb24iLCJtYW5hZ2UtY2xpZW50cyIsInF1ZXJ5LWdyb3VwcyJdfX0sInNjb3BlIjoib3BlbmlkIGVtYWlsIHByb2ZpbGUiLCJzaWQiOiJlZjRlMDk5Zi0xZjA4LTQ2NzAtOGZhNi0yYjhiNzhlMDVjMzEiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsInByZWZlcnJlZF91c2VybmFtZSI6ImFkbWluIn0.FK6DhVzpCRFmef2acD2Hmc149e1GTOCGz13dZA828crFbG8j4uhpkoNpiZqdyOPmDtMQ-OebNfjTAUaOt2sS1FmEIBgb9IddcpHKNJOquRjdzQNsX09bX8pFUq1haGwKh6_QmABNOBcT-kQNDSZO-aq7-8FoO9PYa0GWvBRcbcx0W_ngyb7xHglaZTElzcDPBcUTW6llVTTTFygn55smwdxTZ7-tEsMVGM5gNuHwJyLB51HI5KDWrwgUm1hqhhRzvcoutDEAB_HSEXGNNeF7fjP9Qx6q04b7fKOTtnIlXsu3oYW4va9y754llMSJ7w8U-y7yI6Tm2UdNMdYqju7hAA \
--id=api-gateekeper \
--name="Identity API Gatekeeper" \
--description="Client to be used by Identity API Gatekeeper" \
--resource="Eric space" --uris=/eric/* --users=eric \
--resource="Alice space" --uris=/alice/* --users=alice \
--resource="Admin space" --uris=/admin/* --roles=admin
```

Where:
- -e is the environment (development, demo or production)
- -u is the username
- -p is the password
- -t is the bearer access token
- --id is the clientId
- --name is the client name
- --description the client description
- --resource is the name of the resource
- --uris is the list of resource uris
- --users is the list of users with access to the resource
- --roles is the list of roles with acess to the resource

For more information:
```bash
sh create-client.sh -h
```
### Using Identity API

Also, an API was developed to interact more easily with the Keycloak API, that allows client, resource, policies and permissions management. The API documentation can be found in: https://identity.api.eoepca.org/docs (access granted after signing in into eoepca-portal)

## Gatekeeper

Gatekeeper is an authentication and authorization proxy. The gatekeeper is also deployed along the identity-service, with its own configuration file:

For example **identity-api-gatekeeper.yaml:**

```
client-id: identity-api
discovery-url: https://identity.keycloak.develop.eoepca.org/realms/master
no-redirects: true
no-proxy: true
enable-uma: true
cookie-domain: develop.eoepca.org
cookie-access-name: auth_user_id
cookie-refresh-name: auth_refresh_token
enable-metrics: true
enable-logging: true
enable-request-id: true
enable-login-handler: true
enable-refresh-tokens: true
enable-logout-redirect: true
listen: :3000
listen-admin: :4000
```

## Additional Information

Additional information regarding the _Identity Service_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/identity-service)
* [Wiki](https://github.com/EOEPCA/um-identity-service/wiki)
* [GitHub Repository](https://github.com/EOEPCA/um-identity-service)