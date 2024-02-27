# Simple Deployment

## Overview

A deployment wrapper script has been prepared for a 'simple' deployment - designed to get a core local deployment of the primary servies.

The script [`deploy/simple/simple`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/simple/simple) achieves this by appropriate [configuration of the environment variables](scripted-deployment.md#environment-variables), before launching the [eoepca.sh deployment script](scripted-deployment.md#command-line-arguments). The deployment configuration is captured in the file [`deploy/simple/simple-options`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/simple/simple-options).

The simple deployment applies the following configuration:

* Assumes a private deployment - i.e. no external-facing IP/ingress, and hence no TLS<br>
  _To configure an external-facing deployment with TLS protection, then see section [Public Deployment](scripted-deployment.md#public-deployment)_
* No TLS for service ingress endpoints
* Configuration of 'open' interfaces - i.e. service/API endpoints that are not protected and can accessed without authentication. This facilitates experimentation with the services
* Configuration of ADES stage-out to a local instance of `minio`, to avoid the need to create a Workspace for each user

## Initiate Deployment

Deployment is initiated by invoking the script...

```
./deploy/simple/simple
```

See section [Deployment](scripted-deployment.md#deployment) for more details regarding the outcome of the scripted deployment.

## Post-deploy Manual Steps

To complete the deployment, see section [Post-deployment Manual Steps](./scripted-deployment.md#post-deployment-manual-steps) of the [Scripted Deployment](./scripted-deployment.md) page.
