# Application Deployment & Execution Service (ADES)

The _ADES_ provides a platform-hosted execution engine through which users can initiate parameterised processing jobs using applications made available within the platform - supporting the efficient execution of the processing 'close to the data'. Users can deploy specific 'applications' to the ADES, which may be their own applications, or those published by other platform users.

## Helm Chart

The _ADES_ is deployed via the `ades` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `ades` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/ades#readme).

```bash
helm install --values ades-values.yaml ades eoepca/ades
```

## Values

At minimum, values for the following attributes should be specified:

* Details of the _S3 Object Store_ for stage-out of processing results
* Dynamic provisioning _StorageClass_ of `ReadWriteMany` storage
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the ADES will **not** be protected by the `resource-guard` component - ref. [Resource Protection](../resource-protection). Otherwise the ingress will be handled by the `resource-guard` - use `ingress.enabled: false`._

**Example `ades-values.yaml`...**

```yaml
workflowExecutor:
  inputs:
    STAGEOUT_AWS_SERVICEURL: http://minio.192.168.49.123.nip.io
    STAGEOUT_AWS_ACCESS_KEY_ID: eoepca
    STAGEOUT_AWS_SECRET_ACCESS_KEY: changeme
    STAGEOUT_AWS_REGION: us-east-1
    STAGEOUT_OUTPUT: s3://eoepca
  processingStorageClass: standard
persistence:
  storageClass: standard
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "false"
  hosts:
    - host: ades.192.168.49.123.nip.io
      paths: ["/"]
  tls:
    - hosts:
        - ades.192.168.49.123.nip.io
      secretName: ades-tls
```

## Workspace Integration

The ADES has the facility to integrate with the EOEPCA [Workspace component](../workspace/) for registration of staged-out processing results. This is disabled by default (`useResourceManager: false`).

When enabled, the ADES will register the staged-out products with the user's Workspace, such that they are indexed and available via the user's Resource Catalogue and Data Access services.

**Example `ades-values.yaml` (snippet)...**

```yaml
workflowExecutor:
  ...
  useResourceManager: "true"
  resourceManagerWorkspacePrefix: "guide-user"
  resourceManagerEndpoint: "https://workspace-api.192.168.49.123.nip.io"
  platformDomain: "https://auth.192.168.49.123.nip.io"
  ...
```

The value `resourceManagerWorkspacePrefix` must be consistent with that [configured for the Workspace API deployment](../workspace/#values), (ref. value `prefixForName`).

## Protection

As described in [section Resource Protection](../resource-protection), the `resource-guard` component can be inserted into the request path of the ADES service to provide access authorization decisions

```bash
helm install --values ades-guard-values.yaml ades-guard eoepca/resource-guard
```

The `resource-guard` must be configured with the values applicable to the ADES for the _Policy Enforcement Point_ (`pep-engine`) and the _UMA User Agent_...

**Example `ades-guard-values.yaml`...**

```yaml
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: ades
  pep: ades-pep
  domain: 192.168.49.123.nip.io
  nginxIp: 192.168.49.123
  certManager:
    clusterIssuer: letsencrypt-staging
#---------------------------------------------------------------------------
# PEP values
#---------------------------------------------------------------------------
pep-engine:
  configMap:
    asHostname: auth
    pdpHostname: auth
  # customDefaultResources:
  #   - name: "Eric's space"
  #     description: "Protected Access for eric to his space in the ADES"
  #     resource_uri: "/eric"
  #     scopes: []
  #     default_owner: "a9812efe-fc0c-49d3-8115-0f36883a84b9"
  #   - name: "Bob's space"
  #     description: "Protected Access for bob to his space in the ADES"
  #     resource_uri: "/bob"
  #     scopes: []
  #     default_owner: "4ccae3a1-3fad-4ffe-bfa7-cce851143780"
  volumeClaim:
    name: eoepca-proc-pvc
    create: false
#---------------------------------------------------------------------------
# UMA User Agent values
#---------------------------------------------------------------------------
uma-user-agent:
  fullnameOverride: ades-agent
  nginxIntegration:
    enabled: true
    hosts:
      - host: ades
        paths:
          - path: /(.*)
            service:
              name: ades
              port: 80
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/rewrite-target: /$1
  client:
    credentialsSecretName: "proc-client"
  logging:
    level: "info"
  unauthorizedResponse: 'Bearer realm="https://auth.192.168.49.123.nip.io/oxauth/auth/passport/passportlogin.htm"'
  openAccess: false
  insecureTlsSkipVerify: true
```

**NOTES:**

* TLS is enabled by the specification of `certManager.clusterIssuer`
* The `letsencrypt` Cluster Issuer relies upon the deployment being accessible from the public internet via the `global.domain` DNS name. If this is not the case, e.g. for a local minikube deployment in which this is unlikely to be so. In this case the TLS will fall-back to the self-signed certificate built-in to the nginx ingress controller
* `insecureTlsSkipVerify` may be required in the case that good TLS certificates cannot be established, e.g. if letsencrypt cannot be used for a local deployment. Otherwise the certificates offered by login-service _Authorization Server_ will fail validation in the _Resource Guard_.
* `customDefaultResources` can be specified to apply initial protection to the endpoint

### Client Secret

The Resource Guard requires confidential client credentials to be configured through the file `client.yaml`, delivered via a kubernetes secret..

**Example `client.yaml`...**

```yaml
client-id: a98ba66e-e876-46e1-8619-5e130a38d1a4
client-secret: 73914cfc-c7dd-4b54-8807-ce17c3645558
```

**Example `Secret`...**

```bash
kubectl -n proc create secret generic proc-client \
  --from-file=client.yaml \
  --dry-run=client -o yaml \
  > proc-client-secret.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: proc-client
  namespace: proc
data:
  client.yaml: Y2xpZW50LWlkOiBhOThiYTY2ZS1lODc2LTQ2ZTEtODYxOS01ZTEzMGEzOGQxYTQKY2xpZW50LXNlY3JldDogNzM5MTRjZmMtYzdkZC00YjU0LTg4MDctY2UxN2MzNjQ1NTU4
```

The client credentials are obtained by registration of a client at the login service web interface - e.g. https://auth.192.168.49.123.nip.io. In addition there is a helper script that can be used to create a basic client and obtain the credentials, as described in [section Resource Protection](../resource-protection/#client-registration)...
```bash
./local-deploy/bin/register-client auth.192.168.49.123.nip.io "Resource Guard" | tee client.yaml
```

## ADES Usage Samples

This section includes some sample requests to test the deployed ADES.

NOTES:

1. It assumed that the ADES is subject to access protection (ref. [Resource Protection](../resource-protection)), in which case a User ID Token must be provided with the request - typically in the HTTP header `X-User-Id`.<br>
   See section [User ID Token](../resource-protection/#user-id-token) for more details.
2. The samples assume a user `eric`

### List Processes

List available processes.

```
curl --location --request GET 'https://ades.192.168.49.123.nip.io/eric/wps3/processes' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

### Deploy Process

Deploy the sample application `snuggs`.

```
curl --location --request POST 'https://ades.192.168.49.123.nip.io/eric/wps3/processes' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--data-raw '{
    "inputs": [
        {
            "id": "applicationPackage",
            "input": {
                "format": {
                    "mimeType": "application/cwl"
                },
                "value": {
                    "href": "https://raw.githubusercontent.com/EOEPCA/app-snuggs/main/app-package.cwl"
                }
            }
        }
    ],
    "outputs": [
        {
            "format": {
                "mimeType": "string",
                "schema": "string",
                "encoding": "string"
            },
            "id": "deployResult",
            "transmissionMode": "value"
        }
    ],
    "mode": "auto",
    "response": "raw"
}'
```

### Get Process Details

Get details for a deployed process.

```
curl --location --request GET 'https://ades.192.168.49.123.nip.io/eric/wps3/processes/snuggs-0_3_0' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

### Execute Process

Execute a process with supplied parameterisation.

```
curl --location --request POST 'https://ades.192.168.49.123.nip.io/eric/wps3/processes/snuggs-0_3_0/jobs' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json' \
--header 'Content-Type: application/json' \
--data-raw '{
    "inputs": [
        {
            "id": "input_reference",
            "input": {
                "dataType": {
                    "name": "application/json"
                },
                "value": "https://earth-search.aws.element84.com/v0/collections/sentinel-s2-l2a-cogs/items/S2B_36RTT_20191205_0_L2A"
            }
        },
        {
            "id": "s_expression",
            "input": {
                "dataType": {
                    "name": "string"
                },
                "value": "ndvi:(/ (- B05 B03) (+ B05 B03))"
            }
        }
    ],
    "outputs": [
        {
            "format": {
                "mimeType": "string",
                "schema": "string",
                "encoding": "string"
            },
            "id": "wf_outputs",
            "transmissionMode": "value"
        }
    ],
    "mode": "auto",
    "response": "raw"
}'
```

### Job Status

Once a processes execution has been initiated then its progress can monitored via a job-specific URL that is returned in the HTTP response headers of the execute request.

```
curl --location --request GET 'https://ades.192.168.49.123.nip.io/eric/watchjob/processes/snuggs-0_3_0/jobs/2e0fabf4-4ed6-11ec-b857-626a98159388' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

### Job Result

Once the job execution has completed, then the results can be obtained.

```
curl --location --request GET 'https://ades.192.168.49.123.nip.io/eric/watchjob/processes/snuggs-0_3_0/jobs/2e0fabf4-4ed6-11ec-b857-626a98159388/result' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

### Undeploy Process

A process can be deleted (undeployed).

```
curl --location --request DELETE 'https://ades.192.168.49.123.nip.io/eric/wps3/processes/snuggs-0_3_0' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

## Additional Information

Additional information regarding the _ADES_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/ades)
* [Wiki](https://github.com/EOEPCA/proc-ades/wiki)
* [GitHub Repository](https://github.com/EOEPCA/proc-ades)
