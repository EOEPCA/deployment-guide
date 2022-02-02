# Container Registry

To support the development (ref. [Processor Development Environment](../pde/)) and deployment/execution (ref. [ADES](../ades/)) of user-defined applications, we deploy a container registry to host container images. This is provied by a deployment of the [Harbor artefact repository](https://goharbor.io/).

## Helm Chart

_Harbor_ is deployed via the `harbor` helm chart from the [Harbor Helm Chart Repository](https://helm.goharbor.io).

```bash
helm install --values harbor-values.yaml harbor harbor --repo https://helm.goharbor.io
```

## Values

The chart is configured via values that are fully documented on the [Harbor website](https://goharbor.io/docs/2.4.0/install-config/harbor-ha-helm/).

Example...

```yaml
expose:
  ingress:
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: letsencrypt-production
      nginx.ingress.kubernetes.io/proxy-read-timeout: '600'

      # from chart:
      ingress.kubernetes.io/ssl-redirect: letsencrypt-production
      ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/ssl-redirect: letsencrypt-production
      nginx.ingress.kubernetes.io/proxy-body-size: "0"

    hosts:
      core: harbor.192.168.49.123.nip.io
      notary: harbor-notary.192.168.49.123.nip.io

persistence:
  persistentVolumeClaim:
    registry:
      storageClass: standard
    chartmuseum:
      storageClass: standard
    jobservice:
      storageClass: standard
    database:
      storageClass: standard
    redis:
      storageClass: standard
    trivy:
      storageClass: standard

externalURL: https://harbor.192.168.49.123.nip.io
# initial password for logging in with user "admin"
harborAdminPassword: "changeme"

chartmuseum:
  enabled: false
trivy:
  enabled: false
notary:
  enabled: false
```

**NOTES:**

* We specify use of 'valid' certificates from Letsencrypt 'production'. The Workspace API, which calls the Harbor API, expects valid certificates and will thus fail if presented with TLS certificates that fail validation.
* The `letsencrypt-production` Cluster Issuer relies upon the deployment being accessible from the public internet via the `expose.ingress.hosts.core` DNS name. If this is not the case, e.g. for a local minikube deployment in which this is unlikely to be so. In this case the TLS will fall-back to the self-signed certificate built-in to the nginx ingress controller. The Workspace API will not like this.

## Container Registry Usage

After deployemnt Harbor is accessible via its [web interface](https://harbor.192.168.49.123.nip.io/) at `https://harbor.<domain>/`<br>e.g. [https://harbor.192.168.49.123.nip.io/](https://harbor.192.168.49.123.nip.io/).

Login as the admin user with the password specified in the helm values.

## Additional Information

Additional information regarding the _Container Registry_ can be found at:

* [Web Site](https://goharbor.io/)
* [Helm Chart Repository](https://helm.goharbor.io/)
* [Helm Chart Description](https://goharbor.io/docs/2.4.0/install-config/harbor-ha-helm/)
* [Harbor Documentation](https://goharbor.io/docs/)
