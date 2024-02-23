# Application Hub Deployment

## Overview

A deployment wrapper script has been prepared for an 'Application Hub' deployment - that provides the Application Hub integrated with the Identity Service (Keycloak) via OIDC for user authentication.

The script [`deploy/apphub/apphub`](https://github.com/EOEPCA/deployment-guide/blob/integration/deploy/apphub/apphub) achieves this by appropriate [configuration of the environment variables](scripted-deployment.md#environment-variables), before launching the [eoepca.sh deployment script](scripted-deployment.md#command-line-arguments). The deployment configuration is captured in the file [`deploy/apphub/apphub-options`](https://github.com/EOEPCA/deployment-guide/blob/integration/deploy/apphub/apphub-options).

The Application Hub deployment applies the following configuration:

* Assumes a private deployment - i.e. no external-facing IP/ingress, and hence no TLS<br>
  _To configure an external-facing deployment with TLS protection, then see section [Public Deployment](scripted-deployment.md#public-deployment)_
* No TLS for service ingress endpoints
* Services deployed:
    * Identity Service (Keycloak)<br>
      _With test users eric, bob and alice created in Keycloak_
    * Application Hub<br>
      _User eric and bob predefined as admin users_
* Other eoepca services not deployed

## Initiate Deployment

Deployment is initiated by invoking the script...

```
./deploy/apphub/apphub
```

The Identity Service (Keycloak) is accessed at the following endpoints...

* [http://identity.keycloak.192-168-49-2.nip.io/](http://identity.keycloak.192-168-49-2.nip.io/)
* [http://identity-api-protected.192-168-49-2.nip.io/docs](http://identity-api-protected.192-168-49-2.nip.io/docs) (Swagger docs for the API)

The Application Hub is accessed at the endpoint - [http://applicationhub.192-168-49-2.nip.io/](http://applicationhub.192-168-49-2.nip.io/).

## Post-deployment Manual Steps

The creation and configuration of the OIDC client are now performed automatically by the scripted deployment.

However, it remains necessary to manually configure the Groups and Users (test users `eric` and `bob`), as described in section [Post-deployment Manual Steps - Groups and Users](../eoepca/application-hub.md#groups-and-users).

## Application Hub Notes

### Login

Authentication is made via the `Sign in with EOEPCA` button on the service home page - which redirects to Keycloak for authentication.

With the out-of-the-box configuration user `eric` or `bob` should be used with default password `changeme`. Users eric and bob are currently predefined within the helm chart as admin users - see [https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/files/hub/jupyter_config.py#L171](https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/files/hub/jupyter_config.py#L171).

### Spawning Applications

Once logged in, the service list is presented for spawning of applications. Note that this list of applications is currently defined within the helm chart - see [https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/files/hub/config.yml](https://github.com/EOEPCA/helm-charts/blob/main/charts/application-hub/files/hub/config.yml).

From the list, a service is selected and the `Start` button initiates spawning.

For a clean deployment, the first spawn of each application may take some time whilst the container image representing the application is downloaded to the node. Subsequent invocations (at least on the same node) should be much faster. Once running, the application continues (in the background) until stopped by the user using the `Stop Server` button on the user's home screen.

The current JupyterHub configuration assumes a single application service (per user) running at a time - i.e. the current application must be stopped before the next can be started. There is an alternative configuration in which applications can be run in parallel and their lifecycles individually managed.

### Returning to the Home Screen

The launched applications do not (yet) have a navigation link 'out' of the application back to the home screen.

Therefore, it is necessary to manually modify the url in the browser address bar to `/hub/home` to navigate to the home screen - from where the current running server can be stopped or re-entered.

### IAT - JupyterLab

Following instantiation, the IAT application (Interactive Analysis Tool) defaults to the 'Jupyter Notebook' view (`/user/<user>/tree`) - rather than the Jupyter Lab view (`/user/<user>/lab`).

To switch to the Jupyter Lab view it is necessary to manually edit the url path from `/user/<user>/tree` to `/user/<user>/lab`. It is intended to update the default to this Jupyter Lab path.
