# User Management Deployment

A deployment wrapper script has been prepared for a 'user management' deployment - that is focused on the _Login Service_, _PDP_ and _User Profile_.

The script [`deploy/userman/userman`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/userman/userman) achieves this by appropriate [configuration of the environment variables](scripted-deployment.md#environment-variables), before launching the [eoepca.sh deployment script](scripted-deployment.md#command-line-arguments). The deployment configuration is captured in the file [`deploy/userman/userman-options`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/userman/userman-options).

The user-management deployment applies the following configuration:

* Assumes a public IP (which allows configuration of TLS)<br>
  _In case of no public IP then see section [Private Deployment](scripted-deployment.md#private-deployment)_
* TLS via letsencrypt
* Services deployed:
    * Login Service
    * Policy Decision Point (PDP)
    * User Profile
* Other eoepca services not deployed

## Initiate Deployment

Deployment is initiated by invoking the script...

```
./deploy/userman/userman
```

The _Login Service_ is accessed at the endpoint `auth.<domain>` - e.g. `auth.192.168.49.2.nip.io`.
