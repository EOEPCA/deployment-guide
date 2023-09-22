# User Profile

The _User Profile_ represents the user's 'account' within the platform.

## Helm Chart

The _User Profile_ is deployed via the `user-profile` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `user-profile` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/user-profile#readme).

```bash
helm install --version 1.1.6 --values user-profile-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  user-profile user-profile
```

## Values

At minimum, values for the following attributes should be specified:

* Public hostname of the Authorization Server, e.g. `auth.192-168-49-2.nip.io`
* IP Address of the public facing reverse proxy (Nginx Ingress Controller), e.g. `192.168.49.2`
* Name of Persistent Volume Claim for `user-profile` persistence, e.g. `eoepca-userman-pvc`<br>
  _The boolen value `volumeClaim.create` can be used for the PVC to be created by the helm release. This creates a volume of type `host-path` and, hence, is only useful for single-node development usage._

Example `user-profile-values.yaml`...
```yaml
global:
  domain: auth.192-168-49-2.nip.io
  nginxIp: 192.168.49.2
volumeClaim:
  name: eoepca-userman-pvc
  create: false
```

## User Profile Usage

The User Profile is accessed through the [`/web_ui`](http://auth.kube.guide.eoepca.org/web_ui) path of the Login Service, e.g. http://auth.kube.guide.eoepca.org/web_ui.

## Additional Information

Additional information regarding the _User Profile_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/user-profile)
* [Wiki](https://github.com/EOEPCA/um-user-profile/wiki)
* [GitHub Repository](https://github.com/EOEPCA/um-user-profile)
