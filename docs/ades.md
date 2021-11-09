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
  _Note that this is only required in the case that the ADES will **not** be protected by the `resource-guard` component - ref. [Resource Protection](./resource-protection.md). Otherwise the ingress will be handled by the `resource-guard` - use `ingress.enabled: false`._

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

## Protection

As described in [section Resource Protection](./resource-protection.md), the `resource-guard` component can be inserted into the request path of the ADES service to provide access authorization decisions...

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
  # certManager:
  #   clusterIssuer: letsencrypt-staging
#---------------------------------------------------------------------------
# PEP values
#---------------------------------------------------------------------------
pep-engine:
  configMap:
    asHostname: auth
    pdpHostname: auth
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
```

**_NOTE that the `letsencrypt` Cluster Issuer can only be used if the deployment is accessible from the public internet via the `global.domain` DNS name. If this is not the case, e.g. for a local minikube deployment, then this is unlikely to be the case, and so should be omitted._**

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
./local-deploy/bin/register-client auth.192.168.49.123.nip.io "Resource Guard" client.yaml
```

## Additional Information

Additional information regarding the _Login Service_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/ades)
* [Wiki](https://github.com/EOEPCA/proc-ades/wiki)
* [GitHub Repository](https://github.com/EOEPCA/proc-ades)
