# Login Service

The _Login Service_ provides the platform _Authorization Server_ for authenticated user identity and request authorization.

## Helm Chart

The _Login Service_ is deployed via the `login-service` helm chart from the [EOEPCA Helm Chart Repository](https://eoepca.github.io/helm-charts).

The chart is configured via values that are fully documented in the [README for the `login-service` chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/login-service#readme).

```bash
helm install --version 1.2.8 --values login-service-values.yaml \
  --repo https://eoepca.github.io/helm-charts \
  login-service login-service
```

## Values

At minimum, values for the following attributes should be specified:

* Public hostname of the Authorization Server, e.g. `auth.192-168-49-2.nip.io`
* IP Address of the public facing reverse proxy (Nginx Ingress Controller), e.g. `192.168.49.2`
* Kubernetes `namespace` for the login-service components
* Initial password for the admin user<br>
  _Note that the password must meet the complexity: at least 6 characters and include one uppercase letter, one lowercase letter, one digit, and one special character_
* Name of Persistent Volume Claim for `login-service` persistence, e.g. `eoepca-userman-pvc`<br>
  _The boolen value `volumeClaim.create` can be used for the PVC to be created by the helm release. This creates a volume of type `host-path` and, hence, is only useful for single-node development usage._
* TLS Certificate Provider, e.g. `letsencrypt-production`

Example `login-service-values.yaml`...
```yaml
global:
  domain: auth.192-168-49-2.nip.io
  nginxIp: 192.168.49.2
  namespace: um
volumeClaim:
  name: eoepca-userman-pvc
  create: false
config:
  domain: auth.192-168-49-2.nip.io
  adminPass: Chang3me!
  ldapPass: Chang3me!
  volumeClaim:
    name: eoepca-userman-pvc
opendj:
  volumeClaim:
    name: eoepca-userman-pvc
  resources:
    requests:
      cpu: 100m
      memory: 300Mi
oxauth:
  volumeClaim:
    name: eoepca-userman-pvc
  resources:
    requests:
      cpu: 100m
      memory: 1000Mi
oxtrust:
  volumeClaim:
    name: eoepca-userman-pvc
  resources: 
    requests:
      cpu: 100m
      memory: 1500Mi
oxpassport:
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
nginx:
  ingress:
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-production
    hosts:
      - auth.192-168-49-2.nip.io
    tls:
      - hosts:
          - auth.192-168-49-2.nip.io
        secretName: login-service-tls
```

!!! note
    The `resources:` above have been limited for the benefit of a minikube deployment. For a production deployment the values should be tuned (upwards) according to operational needs.

## Post-deployment Manual Steps

The deployment of the Login Service has been designed, as far as possible, to automate the configuration. However, there remain some steps that must be performed manually after the scripted deployment has completed...

* [Configure `UMA Resource Lifetime`](#uma-resource-lifetime)
* [Configure `Operator` user](#configure-operator-user)

### UMA Resource Lifetime

The Login Service maintains a background service that 'cleans' UMA resources that are older than aa certain age - by default 30 days (`2592000` secs). This lifetime does not fit the approach we are adopting, and so we must update this lifetime value to avoid the unexpected removal of UMA resources that would cause unexpected failures in policy enforcement.

* In a browser, navigate to the Login Service (Gluu) - `https://auth.192-168-49-2.nip.io/` - and login as the `admin` user
* Open `Configuration -> JSON Configuration -> OxAuth Configuration`
* Search for the setting `umaResourceLifetime`
* Update the values of `umaResourceLifetime` to `2147483647`
* Select to `Save Configuration`
* Restart the `oxauth` deployment...<br>
  ```
  kubectl -n um rollout restart deploy/login-service-oxauth
  ```

### Configure `Operator` user

The default resource protection establishes policy in which 'operator' privilege is required for some services, such as the Workspace API. Thus, we need to configure a user with this privilege. For convenience we add this attribute to the built-in `admin` user - but alternatively you may choose to create a new user for this role.

* In a browser, navigate to the Login Service (Gluu) - `https://auth.192-168-49-2.nip.io/` - and login as the `admin` user
* Select `Users -> Manage People` and search for user `admin`
* For user `admin` select `Available User Claims -> gluuCustomPerson`
* Select `Is Operator` and ensure the value is set `True`
* Select `Update` to confirm

## Login Service Usage

Once the deployment has been completed successfully, the Login Service is accessed at the endpoint `https://auth.192-168-49-2.nip.io/`, configured by your domain - e.g. [https://auth.192-168-49-2.nip.io/](https://auth.192-168-49-2.nip.io/).

Login as the `admin` user with the credentials configured in the helm values - ref. `adminPass` / `ldapPass`.

Typical first actions to undertake through the Gluu web interface include creation of users and clients.

## Additional Information

Additional information regarding the _Login Service_ can be found at:

* [Helm Chart](https://github.com/EOEPCA/helm-charts/tree/main/charts/login-service)
* [Wiki](https://github.com/EOEPCA/um-login-service/wiki)
* [GitHub Repository](https://github.com/EOEPCA/um-login-service)
