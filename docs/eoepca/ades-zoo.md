# **ZOO-Project DRU --NEW--**

<div style="text-align: center; font-weight: bold; font-style: italic;">
  ADES - Application Deployment & Execution Service
</div>

!!! note
    With EOEPCA release 1.4, the ADES implementation has been significantly reworked and fully aligned with the upstream [ZOO-Project](https://www.zoo-project.org/) ([GitHub](https://github.com/ZOO-Project/ZOO-Project)). This `zoo-project-dru` version deprecates the previous `proc-ades` implementation.

    With this transition, there are some functional changes to be aware of...

    * **Service Endpoint**<br>
      With `zoo-project-dru` the OGC API Processes endpoint is at the path `/<username>/ogc-api/processes` compared to the previous `/<username>/wps3/processes`.
    * **Deployed Application Endpoint**<br>
      The endpoint for a deployed Application no longer appends the version of the Application Package.<br>
      For example, previously the application `convert-url` at version `0.1.2` would result in the endpoint `/<username>/wps3/processes/convert-url_0_1_2`.<br>
      With the new `zoo-project-dru` this same Application Package deployment will result in the endpoint `/<username>/ogc-api/processes/convert-url`.
    * **Deployed Application Version**<br>
      The version of the deployed application is obtained from the Application Package CWL (ref. `s:softwareVersion: 0.1.2`), and is maintained within the metadata for the deployed process that is returned from the APIs `Get Process Details` request.<br>
      In the case that multiple versions of the same Application Package are required to be simultaneously deployed, then this would have to be handled with different CWL documents in which the version is embedded in the workflow `id` (or some other technique that establishes uniqueness of `id` between variants).

The _ADES_ provides a platform-hosted execution engine through which users can initiate parameterised processing jobs using applications made available within the platform - supporting the efficient execution of the processing 'close to the data'. Users can deploy specific 'applications' to the ADES, which may be their own applications, or those published by other platform users.

The ADES provides an implementation of the [OGC API Processes - Part 1: Core](https://docs.ogc.org/is/18-062r2/18-062r2.html) and [Part 2: Deploy, Replace, Undeploy (draft)](https://docs.ogc.org/DRAFTS/20-044.html).

## Helm Chart

The EOEPCA deployment is aligned with the upstream implementation and so relies upon the upstream helm chart that is hosted at the [ZOO-Project Helm Chart Repository](https://zoo-project.github.io/charts/) - in particular the `zoo-project-dru` chart variant.

The chart is configured via values that are fully documented in the [README for the `zoo-project-dru` chart](https://github.com/ZOO-Project/charts/tree/main/zoo-project-dru).

```bash
helm install --version 0.2.6 --values ades-values.yaml \
  --repo https://zoo-project.github.io/charts/ \
  zoo-project-dru zoo-project-dru
```

## Values

The deployment must be configured for you environment. Some significant configuration values are elaborated here...

### Cookie-cutter Template

The implementation `zoo-project-dru` provides the core capabilities for OGC API Processes Parts 1 & 2. The deployemnt of this core must be completed by inetgartion with the 'runner' that executes the processes as Application Packages, and integrates as necessary with other platform services - such as Catalogue, Workspace, etc.

Thus, `zoo-project-dru` is extensible by design via a ['cookie-cutter'](https://cookiecutter.readthedocs.io/en/stable/) that provides the template 'runner' for each Application Package process as it is deployed to the service.

For the purposes of our EOEPCA 'release' as covered by this guide, we provide [`eoepca-proc-service-template`](https://github.com/EOEPCA/eoepca-proc-service-template) as a cookie-cutter implemetation that provides:

* Integration with Kubernetes to run process Application packages, via the Calrissian CWL runner
* Stage-in of inputs as STAC items, integrated as required with S3 object storage
* Stage-out of outputs as a STAC Collection, integrated with S3 object storage and (optionally) user Workspace inetgration

The cookie-cutter template is identified in the helm values...

```yaml
cookiecutter:
  templateUrl: https://github.com/EOEPCA/eoepca-proc-service-template.git
  templateBranch: master
```

The function of the cookie-cutter template is supported some other aspects, that are elaborated below, which must be configured in collaboration with the expectations of the template.<br>
In particular...

* Template parameterisation that is passed through the core `zoo-project-dru` configuration [[ref](#zoo-project-dru-custom-configuration)]
* CWL 'wrapper' files that prepend and append the process Application Package CWL to perform stage-in and stage-out functions [[ref](#stage-in-stage-out)]


### ZOO-Project DRU custom configuration

In order support our `eoepca-proc-service-template` cookie-cutter template, there is a custom `zoo-project-dru` container image that includes the python dependencies that are required by this template. Thus, the deployment must identify the custom container image via helm values...

```yaml
zoofpm:
  image:
    tag: eoepca-092ea7a2c6823dba9c6d52c383a73f5ff92d0762
zookernel:
  image:
    tag: eoepca-092ea7a2c6823dba9c6d52c383a73f5ff92d0762
```

In addition, we can add values to the ZOO-Project DRU `main.cfg` configuration file via helm values. In this case we add some eoepca-specific values that match those that we know to be expected by our `eoepca-proc-service-template` cookie-cutter template. In this way we can effectively use helm values to pass parameters through to the template.

```yaml
customConfig:
  main:
    eoepca: |-
      domain=myplatform.mydomain
      workspace_prefix=ws
```

This is manifest in zoo's `main.cfg` in INI file configuration syntax...

```ini
[eoepca]
domain=myplatform.mydomain
workspace_prefix=ws
```

The presence or otherwise of the `workspace_prefix` parameter dicates whether or not the stage-out step will integrate with the user's Workspace for persistence of the processing results, and registration within the Workspace services.

In the case that `workspace_prefix` is not set, then the object storage specification in the helm values is relied upon...

```yaml
workflow:
  inputs:
    STAGEOUT_AWS_SERVICEURL: https://minio.myplatform.mydomain
    STAGEOUT_AWS_ACCESS_KEY_ID: eoepca
    STAGEOUT_AWS_SECRET_ACCESS_KEY: changeme
    STAGEOUT_AWS_REGION: RegionOne
    STAGEOUT_OUTPUT: eoepca
```

### Stage-in / Stage-out

The ADES hosts applications that are deployed and invoked in accordance with the [OGC Best Practise for Application Package](https://docs.ogc.org/bp/20-089r1.html). Thus, the ADES provides a conformant environment within which the application is integrated for execution. A key part of the ADES's role in this is to faciltate the provision of input data to the application (stage-in), and the handling of the results output at the conclusion of application execution (stage-out).

The `zoo-project-dru` helm chart provides a default implementation via the included files - `main.yaml`, `rules.yaml`, `stagein.yaml` and `stageout.yaml`.

The helm values provides a means through which each of these files can be overriden for reasons of integration with your platform environment...

```yaml
files:
  # Directory 'files/cwlwrapper-assets' - assets for ConfigMap 'XXX-cwlwrapper-config'
  cwlwrapperAssets:
    main.yaml: |-
      <override file content here>
    rules.yaml: |-
      <override file content here>
    stagein.yaml: |-
      <override file content here>
    stageout.yaml: |-
      <override file content here>
```

In the most part the default CWL wrapper files provided with the helm chart are suffient. In particular the `stagein.yaml` implements the stage-in of STAC items that are specified as inputs of type `Directory` in the Application Package CWL.

E.g.
```yaml
    inputs:
      stac:
        label: the image to convert as a STAC item
        doc: the image to convert as a STAC item
        type: Directory

```

Nevertheless, in this guide we provide an override of the `stageout.yaml` in order to organise the processing outputs into a STAC Collection that is then pushed to the designated S3 object storage, including support for the user's workspace storage and resource management services.

The custom stage-out embeds, within the CWL document, the python code required to implement the desired stage-out functionality. This should be regarded as an example that could be adapted for alternative behaviour.

```yaml
cwlVersion: v1.0
class: CommandLineTool
id: stage-out
doc: "Stage-out the results to S3"
inputs:
  process:
    type: string
  collection_id:
    type: string
  STAGEOUT_OUTPUT:
    type: string
  STAGEOUT_AWS_ACCESS_KEY_ID:
    type: string
  STAGEOUT_AWS_SECRET_ACCESS_KEY:
    type: string
  STAGEOUT_AWS_REGION:
    type: string
  STAGEOUT_AWS_SERVICEURL:
    type: string
outputs:
  StacCatalogUri:
    outputBinding:
      outputEval: \${  return "s3://" + inputs.STAGEOUT_OUTPUT + "/" + inputs.process + "/catalog.json"; }
    type: string
baseCommand:
  - python
  - stageout.py
arguments:
  - \$( inputs.wf_outputs.path )
  - \$( inputs.STAGEOUT_OUTPUT )
  - \$( inputs.process )
  - \$( inputs.collection_id )
requirements:
  DockerRequirement:
    dockerPull: ghcr.io/terradue/ogc-eo-application-package-hands-on/stage:1.3.2
  InlineJavascriptRequirement: {}
  EnvVarRequirement:
    envDef:
      AWS_ACCESS_KEY_ID: \$( inputs.STAGEOUT_AWS_ACCESS_KEY_ID )
      AWS_SECRET_ACCESS_KEY: \$( inputs.STAGEOUT_AWS_SECRET_ACCESS_KEY )
      AWS_REGION: \$( inputs.STAGEOUT_AWS_REGION )
      AWS_S3_ENDPOINT: \$( inputs.STAGEOUT_AWS_SERVICEURL )
  InitialWorkDirRequirement:
    listing:
      - entryname: stageout.py
        entry: |-
          import sys
          import shutil
          import os
          import pystac

          cat_url = sys.argv[1]

          shutil.copytree(cat_url, "/tmp/catalog")
          cat = pystac.read_file(os.path.join("/tmp/catalog", "catalog.json"))

          ...
```

The helm chart values provide the opportunity to pass through additional inputs - to satisfy the input specifications that are specified in the `cwlwrapperAssets` files...

```yaml
workflow:
  inputs:
    STAGEIN_AWS_SERVICEURL: http://data.cloudferro.com
    STAGEIN_AWS_ACCESS_KEY_ID: test
    STAGEIN_AWS_SECRET_ACCESS_KEY: test
    STAGEIN_AWS_REGION: RegionOne
    STAGEOUT_AWS_SERVICEURL: https://minio.myplatform.mydomain
    STAGEOUT_AWS_ACCESS_KEY_ID: eoepca
    STAGEOUT_AWS_SECRET_ACCESS_KEY: changeme
    STAGEOUT_AWS_REGION: RegionOne
    STAGEOUT_OUTPUT: eoepca
```

### Node Selection

The `zoo-project-dru` services uses a _Node Selector_ to determine the node(s) upon which the processing execution is run. This is configured as a matching rule in the helm values, and must be tailored to your cluster.

For example, for minikube...

```yaml
workflow:
  nodeSelector:
    minikube.k8s.io/primary: "true"
```

### Ingress

Ingress can be enabled and configured to establish (reverse-proxy) external access to the `zoo-project-dru` services.

!!! hosturl
    In the case that protection is enabled - e.g. via Resource Guard - then it is likely that ingress should be disabled here, since the ingress will instead be handled by the protection.

    In this case, the `hosturl` parameter should be set to reflect the public url through the service will be accessed.

    In the case that ingress is enabled then it is not necessary to specify the `hosturl`, since it will be taken from the `ingress.hosts[0].host` value.

**Ingress disabled...**

```yaml
ingress:
  enabled: false
  hosturl: zoo.myplatform.mydomain

```

**Ingress enabled...**

```yaml
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: true
    nginx.ingress.kubernetes.io/ssl-redirect: true
    cert-manager.io/cluster-issuer: letsencrypt-production
  hosts:
  - host: zoo-open.myplatform.mydomain
    paths:
    - path: /
      pathType: ImplementationSpecific
  tls:
  - hosts:
    - zoo-open.myplatform.mydomain
    secretName: zoo-open-tls
```

The above example assumes that TLS should be enabled via Letsencrypt as certificate provider - see section [Letsencrypt Certificates](../cluster/cluster-prerequisites.md#letsencrypt-certificates).

### Persistence

Various of the services deployed as part of `zoo-project-dru` rely upon dynamic provisioning of persistent storage volumes.

A number of helm values are impacted by this setting, which must be configured with the _Storage Class_ appropriate to your cluster. For example, using the minikube `standard` storage class...

```yaml
workflow:
  storageClass: standard
persistence:
  procServicesStorageClass: standard
  storageClass: standard
  tmpStorageClass: standard
postgresql:
  primary:
    persistence:
      storageClass: standard
  readReplicas:
    persistence:
      storageClass: standard
rabbitmq:
  persistence:
    storageClass: standard
```

### Built-in IAM

ZOO-Project DRU has a built-in capability for Identity & Access Management (IAM), in which the zoo-project-dru service is configured as an OIDC client of an OIDC Identity Provider service.

This capability is disabled by the default deployment offered by this guide (`ingress.enabled: false`) - which instead (optionally) applies resource protection using the EOEPCA IAM solution. Nevertheless, the built-in IAM can be enabled and configured through helm values.

For example...

```yaml
iam: 
  enabled: true
  openIdConnectUrl: https://myauth.mydomain.myplatform/realms/myrealm/.well-known/openid-configuration
  type: openIdConnect
  name: OpenIDAuth
  realm: Secured section
```

## Protection

zzz

## Protection OLD

As described in [section Resource Protection](resource-protection-gluu.md), the `resource-guard` component can be inserted into the request path of the `zoo-project-dru` service to provide access authorization decisions

```bash
helm install --version 1.3.3 --values zoo-guard-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  zoo-guard resource-guard
```

The `resource-guard` must be configured with the values applicable to the `zoo-project-dru` for the _Policy Enforcement Point_ (`pep-engine`) and the _UMA User Agent_...

**Example `zoo-guard-values.yaml`...**

```yaml
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: zoo
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
    - name: "ZOO-Project DRU Service for user 'eric'"
      description: "Protected Access for eric to his space in the ADES"
      resource_uri: "/eric"
      scopes: []
      default_owner: "<eric-uuid-in-gluu>"
    - name: "ZOO-Project DRU Service for user 'bob'"
      description: "Protected Access for bob to his space in the ADES"
      resource_uri: "/bob"
      scopes: []
      default_owner: "<bob-uuid-in-gluu>"
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
      - host: zoo
        paths:
          - path: /(.*)
            service:
              name: zoo-project-dru-service
              port: 80
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/rewrite-target: /$1
  client:
    credentialsSecretName: "zoo-client"
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
    * `customDefaultResources` can be specified to apply initial protection to the endpoint. By way of example, the above pre-configures protection for user's `eric` and `bob`.

### Client Secret

The Resource Guard requires confidential client credentials to be configured through the file `client.yaml`, delivered via a kubernetes secret..

**Example `client.yaml`...**

```yaml
client-id: a98ba66e-e876-46e1-8619-5e130a38d1a4
client-secret: 73914cfc-c7dd-4b54-8807-ce17c3645558
```

**Example `Secret`...**

```bash
kubectl -n zoo create secret generic zoo-client \
  --from-file=client.yaml \
  --dry-run=client -o yaml \
  > zoo-client-secret.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: zoo-client
  namespace: zoo
data:
  client.yaml: Y2xpZW50LWlkOiBhOThiYTY2ZS1lODc2LTQ2ZTEtODYxOS01ZTEzMGEzOGQxYTQKY2xpZW50LXNlY3JldDogNzM5MTRjZmMtYzdkZC00YjU0LTg4MDctY2UxN2MzNjQ1NTU4
```

The client credentials are obtained by registration of a client at the login service web interface - e.g. https://auth.192-168-49-2.nip.io. In addition there is a helper script that can be used to create a basic client and obtain the credentials, as described in [section Resource Protection](resource-protection-gluu.md#client-registration)...
```bash
./deploy/bin/register-client auth.192-168-49-2.nip.io "Resource Guard" | tee client.yaml
```

## Service URLs

The `zoo-project-dru` service provides a mutil-user aware set of service interfaces at...

* OGC API Processes: `https://zoo.myplatform.mydomain/<username>/ogc-api/`
* Swagger UI: `https://zoo.myplatform.mydomain/swagger-ui/oapip/`

## Usage Samples

See the [Example Requests](../quickstart/processing-deployment.md#example-requests) in the [Processing Deployment](../quickstart/processing-deployment.md) for sample requests that cans be used to test your deployment, and to learn usage of the OGC API Processes.

## Swagger UI (OpenAPI)

The `zoo-project-dru` service includes a Swagger UI interactive representation of its OpenAPI REST interface - available at the URL `https://zoo.myplatform.mydomain/swagger-ui/oapip/`.

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

* **ZOO-Project DRU...**
    * [Helm Chart](https://github.com/ZOO-Project/charts/tree/main/zoo-project-dru)
    * [Documentation](https://www.zoo-project.org/new/Resources/Documentation)
* **Git Repositories...**
    * [ZOO-Project](https://github.com/ZOO-Project/ZOO-Project)<br>
      _Core OGC API Processes capability_
    * [eoepca-proc-service-template](https://github.com/EOEPCA/eoepca-proc-service-template)<br>
      _Cookie-cutter template for Application Package execution in Kubernetes_
    * [zoo-calrissian-runner](https://github.com/EOEPCA/zoo-calrissian-runner)<br>
      _Python library used by the `eoepca-proc-service-template` to aid orchestration of CWL application packages running in Kubernetes via Calrissian_
    * [pycalrissian](https://github.com/terradue/pycalrissian)<br>
      _Python library used by `zoo-calrissian-runner` to aid interfacing with Calrissian and Kubernetes_
