# Application Deployment & Execution Service (ADES)

The _ADES_ provides a platform-hosted execution engine through which users can initiate parameterised processing jobs using applications made available within the platform - supporting the efficient execution of the processing 'close to the data'. Users can deploy specific 'applications' to the ADES, which may be their own applications, or those published by other platform users.

## Helm Chart

The _ADES_ is deployed via the `ades` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `ades` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/ades#readme).

```bash
helm install --version 2.0.24 --values ades-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  ades ades
```

## Values

At minimum, values for the following attributes should be specified:

* Details of the _S3 Object Store_ for stage-out of processing results
* Dynamic provisioning _StorageClass_ of `ReadWriteMany` storage
* (optional) Specification of Ingress for reverse-proxy access to the service<br>
  _Note that this is only required in the case that the ADES will **not** be protected by the `resource-guard` component - ref. [Resource Protection](resource-protection.md). Otherwise the ingress will be handled by the `resource-guard` - use `ingress.enabled: false`._

**Example `ades-values.yaml`...**

```yaml
workflowExecutor:
  inputs:
    # Stage-in from CREODIAS eodata
    # (only works within CREODIAS - i.e. on a Cloudferro VM)
    STAGEIN_AWS_SERVICEURL: http://data.cloudferro.com
    STAGEIN_AWS_ACCESS_KEY_ID: test
    STAGEIN_AWS_SECRET_ACCESS_KEY: test
    STAGEIN_AWS_REGION: RegionOne
    # Stage-out to minio S3
    # (use this if the ADES is not configured to stage-out to the Workspace)
    STAGEOUT_AWS_SERVICEURL: http://minio.192-168-49-2.nip.io
    STAGEOUT_AWS_ACCESS_KEY_ID: eoepca
    STAGEOUT_AWS_SECRET_ACCESS_KEY: changeme
    STAGEOUT_AWS_REGION: us-east-1
    STAGEOUT_OUTPUT: s3://eoepca
  processingStorageClass: standard
  processingVolumeTmpSize: "6Gi"
  processingVolumeOutputSize: "6Gi"
  processingMaxRam: "8Gi"
  processingMaxCores: "4"
wps:
  pepBaseUrl: "http://ades-pep:5576"
  usePep: "false"
persistence:
  storageClass: standard
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
    - host: ades.192-168-49-2.nip.io
      paths: 
        - path: /
          pathType: ImplementationSpecific
  tls:
    - hosts:
        - ades.192-168-49-2.nip.io
      secretName: ades-tls
resources:
  requests:
    cpu: 100m
    memory: 500Mi
  limits:
    cpu: 2
    memory: 4Gi
```

!!! note
    The `resources:` above have been limited for the benefit of a minikube deployment. For a production deployment the values should be tuned (upwards) according to operational needs.<br>
    Additionally, the following ADES values should also be considered...
    ```
    workflowExecutor:
      # Max ram to use for a job
      processingMaxRam: "16Gi"
      # Max number of CPU cores to use concurrently for a job
      processingMaxCores: "8"
    ```

## Stage-in / Stage-out Configuration

The ADES hosts applications that are deployed and invoked in accordance with the [OGC Best Practise for Application Package](https://docs.ogc.org/bp/20-089r1.html). Thus, the ADES provides a conformant environment within which the application is integrated for execution. A key part of the ADES's role in this is to faciltate the provision of input data to the application (stage-in), and the handling of the results output at the conclusion of application execution (stage-out).

The ADES helm chart configures (by default) the ADES with implementations of the stage-in and stage-out functions that use the [Spatio Temporal Asset Router Services](https://github.com/Terradue/Stars) utility.

The ADES provides hooks for system integrators to override these defaults to implement their own stage-in and stage-out behaviour - for example, to integrate with their platform's own catalogue and data offering. The stage-in and stage-out are specified as [CWL](https://www.commonwl.org/) via the helm values...

```yaml
workflowExecutor:
  stagein:
    cwl: |
      cwlVersion: v1.0
      ...
  stageout:
    cwl: |
      cwlVersion: v1.0
      ...
```

For a detailed description see [ADES stage-in/out configuration in the ADES wiki](https://github.com/EOEPCA/proc-ades/wiki/Stagein%20Stageout%20Interfaces).

## Workspace Integration

The ADES has the facility to integrate with the EOEPCA [Workspace component](workspace.md) for registration of staged-out processing results. This is disabled by default (`useResourceManager: false`).

When enabled, the ADES will register the staged-out products with the user's Workspace, such that they are indexed and available via the user's Resource Catalogue and Data Access services.

**Example `ades-values.yaml` (snippet)...**

```yaml
workflowExecutor:
  ...
  useResourceManager: "true"
  resourceManagerWorkspacePrefix: "ws"
  resourceManagerEndpoint: "https://workspace-api.192-168-49-2.nip.io"
  platformDomain: "https://auth.192-168-49-2.nip.io"
  ...
```

The value `resourceManagerWorkspacePrefix` must be consistent with that [configured for the Workspace API deployment](workspace.md#values), (ref. value `prefixForName`).

## Protection

As described in [section Resource Protection](resource-protection.md), the `resource-guard` component can be inserted into the request path of the ADES service to provide access authorization decisions

```bash
helm install --version 1.3.1 --values ades-guard-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  ades-guard resource-guard
```

The `resource-guard` must be configured with the values applicable to the ADES for the _Policy Enforcement Point_ (`pep-engine`) and the _UMA User Agent_...

**Example `ades-guard-values.yaml`...**

```yaml
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: ades
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
  # customDefaultResources:
  #   - name: "ADES Service for user 'eric'"
  #     description: "Protected Access for eric to his space in the ADES"
  #     resource_uri: "/eric"
  #     scopes: []
  #     default_owner: "a9812efe-fc0c-49d3-8115-0f36883a84b9"
  #   - name: "ADES Service for user 'bob'"
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
  unauthorizedResponse: 'Bearer realm="https://portal.192-168-49-2.nip.io/oidc/authenticate/"'
  openAccess: false
  insecureTlsSkipVerify: true
```

!!! note
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

The client credentials are obtained by registration of a client at the login service web interface - e.g. https://auth.192-168-49-2.nip.io. In addition there is a helper script that can be used to create a basic client and obtain the credentials, as described in [section Resource Protection](resource-protection.md#client-registration)...
```bash
./deploy/bin/register-client auth.192-168-49-2.nip.io "Resource Guard" | tee client.yaml
```

## ADES Usage Samples

This section includes some sample requests to test the deployed ADES.

!!! note
    1. It assumed that the ADES is subject to access protection (ref. [Resource Protection](resource-protection.md)), in which case a _User ID Token_ must be provided with the request - typically in the HTTP header, such as `Authorization: Bearer` or `X-User-Id`.<br>
       See section [User ID Token](resource-protection.md#user-id-token) for more details.
    2. The samples assume a user `eric`
    3. The `snuggs` application is used in the example below. _See also [Application Package Example](#application-package-example)._

### List Processes

List available processes.

```
curl --location --request GET 'https://ades.192-168-49-2.nip.io/eric/wps3/processes' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

### Deploy Process

Deploy the sample application `snuggs`.

```
curl --location --request POST 'https://ades.192-168-49-2.nip.io/eric/wps3/processes' \
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
curl --location --request GET 'https://ades.192-168-49-2.nip.io/eric/wps3/processes/snuggs-0_3_0' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

### Execute Process

Execute a process with supplied parameterisation.

```
curl --location --request POST 'https://ades.192-168-49-2.nip.io/eric/wps3/processes/snuggs-0_3_0/jobs' \
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
curl --location --request GET 'https://ades.192-168-49-2.nip.io/eric/watchjob/processes/snuggs-0_3_0/jobs/2e0fabf4-4ed6-11ec-b857-626a98159388' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

### Job Result

Once the job execution has completed, then the results can be obtained.

```
curl --location --request GET 'https://ades.192-168-49-2.nip.io/eric/watchjob/processes/snuggs-0_3_0/jobs/2e0fabf4-4ed6-11ec-b857-626a98159388/result' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

### Undeploy Process

A process can be deleted (undeployed).

```
curl --location --request DELETE 'https://ades.192-168-49-2.nip.io/eric/wps3/processes/snuggs-0_3_0' \
--header 'X-User-Id: <user-id-token>' \
--header 'Accept: application/json'
```

## Application Package Example

For a (trivial) example application package see [Example Application Package](https://github.com/EOEPCA/convert#readme), which provides a description and illustration of the basics of creating an application that integrates with the expectations of the ADES stage-in and stage-out.

For further reference see...

* **Application Packages**
    * [OGC Best Practise for Application Package](https://docs.ogc.org/bp/20-089r1.html)
    * [Example Application Package](https://github.com/EOEPCA/convert#readme)
* **Common Workflow Language (CWL)**
    * [Guide for CWL in Earth Observation](https://cwl-for-eo.github.io/guide/)
    * [CWL Specification](https://www.commonwl.org/v1.2/)
    * [CWL User Guide](https://www.commonwl.org/user_guide/)

## Additional Information

Additional information regarding the _ADES_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/ades)
* [Wiki](https://github.com/EOEPCA/proc-ades/wiki)
* [GitHub Repository](https://github.com/EOEPCA/proc-ades)
* [ADES stage-in/out configuration](https://github.com/EOEPCA/proc-ades/wiki/Stagein%20Stageout%20Interfaces)
