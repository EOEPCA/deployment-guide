# Simple Deployment

A deployment wrapper script has been prepared for a 'simple' deployment - designed to get a core local deployment of the primary servies.

The script [`deploy/simple/simple`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/simple/simple) achieves this by appropriate [configuration of the environment variables](scripted-deployment.md#environment-variables), before launching the [eoepca.sh deployment script](scripted-deployment.md#command-line-arguments). The deployment configuration is captured in the file [`deploy/simple/simple-options`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/simple/simple-options).

The simple deployment applies the following configuration:

* Assumption that the local deployment will not be accessible via a public IP, and hence:
    * Use of minikube driver `none` (`USE_MINIKUBE_NONE_DRIVER`) is suppressed, since the `none` driver is most useful to expose a public service
    * Suppression of use of TLS for service ingress (`USE_TLS`), since the lack of public IP access prevents the ability of `letsencrpt` to provide signed certtificates
* Configuration of 'open' interfaces - i.e. service/API endpoints that are not protected and can accessed without authentication. This facilitates experimentation with the services
* Configuration of ADES stage-out to a local instance of `minio`, on the assumption that access to CREODIAS buckets for stage-out (via Workspace) is not an option
