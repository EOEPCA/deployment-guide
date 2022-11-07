# Simple Deployment

A deployment wrapper script has been prepared for a 'simple' deployment - designed to get a core local deployment of the primary servies.

The script [`deploy/simple/simple`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/simple/simple) achieves this by appropriate [configuration of the environment variables](scripted-deployment.md#environment-variables), before launching the [eoepca.sh deployment script](scripted-deployment.md#command-line-arguments). The deployment configuration is captured in the file [`deploy/simple/simple-options`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/simple/simple-options).

The simple deployment applies the following configuration:

* Assumes a private deployment - i.e. no external-facing IP/ingress, and hence no TLS<br>
  _To configure an external-facing deployment with TLS protection, then see section [Public Deployment](scripted-deployment.md#public-deployment)_
* No TLS for service ingress endpoints
* Configuration of 'open' interfaces - i.e. service/API endpoints that are not protected and can accessed without authentication. This facilitates experimentation with the services
* Configuration of ADES stage-out to a local instance of `minio`, on the assumption that access to CREODIAS buckets for stage-out (via Workspace) is not an option

## Initiate Deployment

Deployment is initiated by invoking the script...

```
./deploy/simple/simple
```

See section [Deployment](scripted-deployment.md#deployment) for more details regarding the outcome of the scripted deployment.

## Protection

See section [Protection](scripted-deployment.md#protection) for more details regarding the protection of the deployed services - which, for the simple deployment, is performed via the script [`deploy/simple/simple-protection`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/simple/simple-protection)...

```
./deploy/simple/simple-protection
```
