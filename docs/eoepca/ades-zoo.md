# **ADES (Processing)**

<div style="text-align: center; font-weight: bold; font-style: italic;">
  ADES - Application Deployment & Execution Service
</div>

## ZOO-Project DRU

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

<div style="text-align: center; font-weight: bold; font-style: italic;">
  DRU - Deploy, Replace, Undeploy - OFC API Processes Part 2
</div>

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
      domain=192-168-49-2.nip.io
      workspace_prefix=ws
```

This is manifest in zoo's `main.cfg` in INI file configuration syntax...

```ini
[eoepca]
domain=192-168-49-2.nip.io
workspace_prefix=ws
```

The presence or otherwise of the `workspace_prefix` parameter dicates whether or not the stage-out step will integrate with the user's Workspace for persistence of the processing results, and registration within the Workspace services.

In the case that `workspace_prefix` is not set, then the object storage specification in the helm values is relied upon...

```yaml
workflow:
  inputs:
    STAGEOUT_AWS_SERVICEURL: https://minio.192-168-49-2.nip.io
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
      outputEval: ${  return "s3://" + inputs.STAGEOUT_OUTPUT + "/" + inputs.process + "/catalog.json"; }
    type: string
baseCommand:
  - python
  - stageout.py
arguments:
  - $( inputs.wf_outputs.path )
  - $( inputs.STAGEOUT_OUTPUT )
  - $( inputs.process )
  - $( inputs.collection_id )
requirements:
  DockerRequirement:
    dockerPull: ghcr.io/terradue/ogc-eo-application-package-hands-on/stage:1.3.2
  InlineJavascriptRequirement: {}
  EnvVarRequirement:
    envDef:
      AWS_ACCESS_KEY_ID: $( inputs.STAGEOUT_AWS_ACCESS_KEY_ID )
      AWS_SECRET_ACCESS_KEY: $( inputs.STAGEOUT_AWS_SECRET_ACCESS_KEY )
      AWS_REGION: $( inputs.STAGEOUT_AWS_REGION )
      AWS_S3_ENDPOINT: $( inputs.STAGEOUT_AWS_SERVICEURL )
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
    STAGEOUT_AWS_SERVICEURL: https://minio.192-168-49-2.nip.io
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
  hosturl: zoo.192-168-49-2.nip.io

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
  - host: zoo-open.192-168-49-2.nip.io
    paths:
    - path: /
      pathType: ImplementationSpecific
  tls:
  - hosts:
    - zoo-open.192-168-49-2.nip.io
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
  openIdConnectUrl: https://keycloak.192-168-49-2.nip.io/realms/master/.well-known/openid-configuration
  type: openIdConnect
  name: OpenIDAuth
  realm: Secured section
```

## Protection

As described in [section Resource Protection (Keycloak)](resource-protection-keycloak.md), the `identity-gatekeeper` component can be inserted into the request path of the `zoo-project-dru` service to provide access authorization decisions

### Gatekeeper

Gatekeeper is deployed using its helm chart...

```bash
helm install zoo-project-dru-protection identity-gatekeeper -f zoo-protection-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  --namespace "zoo" --create-namespace \
  --version 1.0.12
```

The `identity-gatekeeper` must be configured with the values applicable to the `zoo-project-dru` - in particular the specific ingress requirements for the `zoo-project-dru-service`...

**Example `zoo-protection-values.yaml`...**

```yaml
fullnameOverride: zoo-project-dru-protection
config:
  client-id: ades
  discovery-url: https://keycloak.192-168-49-2.nip.io/realms/master
  cookie-domain: 192-168-49-2.nip.io
targetService:
  host: zoo.192-168-49-2.nip.io
  name: zoo-project-dru-service
  port:
    number: 80
secrets:
  # Values for secret 'zoo-project-dru-protection'
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
  # open access to swagger docs
  openUri:
    - ^/(ogc-api/api.*|swagger-ui.*)
```

### Keycloak Client

The Gatekeeper instance relies upon an associated client configured within Keycloak - ref. `client-id: ades` above.

This can be created with the `create-client` helper script, as descirbed in section [Client Registration](./resource-protection-keycloak.md#client-registration).

For example, with path protection for test users...

```bash
../bin/create-client \
  -a https://keycloak.192-168-49-2.nip.io \
  -i https://identity-api.192-168-49-2.nip.io \
  -r "master" \
  -u "admin" \
  -p "changeme" \
  -c "admin-cli" \
  --id=ades \
  --name="ADES Gatekeeper" \
  --secret="changeme" \
  --description="Client to be used by ADES Gatekeeper" \
  --resource="eric" --uris='/eric/*' --scopes=view --users="eric" \
  --resource="bob" --uris='/bob/*' --scopes=view --users="bob" \
  --resource="alice" --uris='/alice/*' --scopes=view --users="alice"
```

## Service URLs

The `zoo-project-dru` service provides a mutil-user aware set of service interfaces at...

* OGC API Processes: `https://zoo.192-168-49-2.nip.io/<username>/ogc-api/`
* Swagger UI: `https://zoo.192-168-49-2.nip.io/swagger-ui/oapip/`

## Usage Samples

See the [Example Requests](../quickstart/processing-deployment.md#example-requests) in the [Processing Deployment](../quickstart/processing-deployment.md) for sample requests that cans be used to test your deployment, and to learn usage of the OGC API Processes.

## Debugging Tips

This section includes some tips that may be useful in debugging errors with deployed application packages.

For debugging, establish a shell session with the `zoofpm` pod...

```bash
$ kubectl -n zoo exec -it deploy/zoo-project-dru-zoofpm -c zoofpm -- bash
```

### Execution Logs

The logs are in the directory `/tmp/zTmp`...

```bash
$ cd /tmp/zTmp/
```

In the log directory, each execution is characterised by a set of files/directories...

* `<appname>_<jobid>_error.log` **<<START HERE**<br>
  _The main log output of the job_
* `<appname>_<jobid>.json`<br>
  _The output (results) of the job_
* `<jobid>_status.json`<br>
  _The overall status of the job_
* `<jobid>_logs.cfg`<br>
  _Index of logs for job workflow steps_
* `convert-url-c6637d4a-d561-11ee-bf3b-0242ac11000e` (directory)<br>
  _Subdirectory with a dedicated log file for each step of the CWL workflow, including the stage-in and stage-out steps_

### Deployed Process 'Executables'

When the process is deployed from its Application Package, then a representation is created using the configured `cookiecutter.templateUrl`.

It may be useful to debug the consequent process files, which are located under the path `/opt/zooservices_user/<username>`, with a dedicated subdirectory for each deployed process - i.e. `/opt/zooservices_user/<username>/<appname>/`.

For example...

```bash
$ cd /opt/zooservices_user/eric/convert-url
$ ls -l
total 28
-rw-rw-r-- 1 www-data www-data     0 Feb 27 11:17 __init__.py
drwxrwxr-x 2 www-data www-data  4096 Feb 27 11:17 __pycache__
-rw-rw-r-- 1 www-data www-data  1408 Feb 27 11:17 app-package.cwl
-rw-rw-r-- 1 www-data www-data 17840 Feb 27 11:17 service.py
```

!!! note
    In the case that the cookie-cutter template is updated, then the process can be re-deployed to force a refresh against the updated template.

## Swagger UI (OpenAPI)

The `zoo-project-dru` service includes a Swagger UI interactive representation of its OpenAPI REST interface - available at the URL `https://zoo.192-168-49-2.nip.io/swagger-ui/oapip/`.

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
