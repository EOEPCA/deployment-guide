# Policy Decision Point

The _Policy Decision Point (PDP)_ provides the platform policy database and associated service for access policy decision requests.

## Helm Chart

The _PDP_ is deployed via the `pdp-engine` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `pdp-engine` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/pdp-engine#readme).

```bash
helm install --version 1.1.6 --values pdp-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  pdp pdp-engine
```

## Values

At minimum, values for the following attributes should be specified:

* Public hostname of the Authorization Server, e.g. `auth.192-168-49-2.nip.io`
* IP Address of the public facing reverse proxy (Nginx Ingress Controller), e.g. `192.168.49.2`
* Name of Persistent Volume Claim for `pdp-engine` persistence, e.g. `eoepca-userman-pvc`<br>
  _The boolen value `volumeClaim.create` can be used for the PVC to be created by the helm release. This creates a volume of type `host-path` and, hence, is only useful for single-node development usage._

Example `pdp-values.yaml`...
```yaml
global:
  nginxIp: 192.168.49.2
  domain: auth.192-168-49-2.nip.io
volumeClaim:
  name: eoepca-userman-pvc
  create: false
```

## Additional Information

Additional information regarding the _PDP_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/pdp-engine)
* [Wiki](https://github.com/EOEPCA/um-pdp-engine/wiki)
* [GitHub Repository](https://github.com/EOEPCA/um-pdp-engine)
