# User Management Deployment

## Overview

A deployment wrapper script has been prepared for a 'user management' deployment - that is focused on the _Identity Service_ (Authorization Server), _Identity API_ and _Gatekeeper_ (Protection Policy Enforcement).

The script [`deploy/userman/userman`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/userman/userman) achieves this by appropriate [configuration of the environment variables](scripted-deployment.md#environment-variables), before launching the [eoepca.sh deployment script](scripted-deployment.md#command-line-arguments). The deployment configuration is captured in the file [`deploy/userman/userman-options`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.4/deploy/userman/userman-options).

The user-management deployment applies the following configuration:

* Assumes a private deployment - i.e. no external-facing IP/ingress, and hence no TLS<br>
  _To configure an external-facing deployment with TLS protection, then see section [Public Deployment](scripted-deployment.md#public-deployment)_
* No TLS for service ingress endpoints
* Services deployed:
    * Identity Service
    * Identity API
    * Gatekeeper instance, protecting the Identity API
* Other eoepca services not deployed

## Initiate Deployment

Deployment is initiated by invoking the script...

```
./deploy/userman/userman
```

The _Identity Service_ is accessed at the endpoint `identity.keycloak.<domain>` - e.g. [`identity.keycloak.192-168-49-2.nip.io`](http://identity.keycloak.192-168-49-2.nip.io/).

The Identity API is accessed at the endpoint `identity-api-protected.<domain>` - e.g. [`identity-api-protected.192-168-49-2.nip.io`](http://identity-api-protected.192-168-49-2.nip.io/).
