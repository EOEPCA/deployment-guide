# Login Service

The _Login Service_ provides the platform _Authorization Server_ for authenticated user identity and request authorization.

## Helm Chart

The _Login Service_ is deployed via the `login-service` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `login-service` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/login-service#readme).

```bash
helm install --values login-service-values.yaml um-login-service eoepca/login-service
```

## Values

At minimum, values for the following attributes should be specified:

* Public hostname of the Authorization Server, e.g. `auth.192.168.49.123.nip.io`
* Initial password for the admin user<br>
  _Note that the password must meet the complexity: at least 6 characters and include one uppercase letter, one lowercase letter, one digit, and one special character_
* IP Address of the public facing reverse proxy (Nginx Ingress Controller), e.g. `192.168.49.123`
* Name of Persistent Volume Claim for `login-service` persistence, e.g. `eoepca-userman-pvc`<br>
  _The boolen value `volumeClaim.create` can be used for the PVC to be created by the helm release. This creates a volume of type `host-path` and, hence, is only useful for single-node development usage._
* TLS Certificate Provider, e.g. `letsencrypt-production`

Example `login-service-values.yaml`...
```yaml
volumeClaim:
  name: eoepca-userman-pvc
  create: false
config:
  domain: auth.192.168.49.123.nip.io
  adminPass: Chang3me!
  ldapPass: Chang3me!
  volumeClaim:
    name: eoepca-userman-pvc
opendj:
  volumeClaim:
    name: eoepca-userman-pvc
oxauth:
  volumeClaim:
    name: eoepca-userman-pvc
oxtrust:
  volumeClaim:
    name: eoepca-userman-pvc
global:
  domain: auth.192.168.49.123.nip.io
  nginxIp: 192.168.49.123
nginx:
  ingress:
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-production
    hosts:
      - auth.192.168.49.123.nip.io
    tls:
      - hosts:
          - auth.192.168.49.123.nip.io
        secretName: login-service-tls
```

## Additional Information

Additional information regarding the _Login Service_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/login-service)
* [Wiki](https://github.com/EOEPCA/um-login-service/wiki)
* [GitHub Repository](https://github.com/EOEPCA/um-login-service)
