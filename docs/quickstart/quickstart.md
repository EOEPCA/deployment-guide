# Quick Start

The deployment of the EOEPCA components and the supporting Kubernetes cluster is described in the sections [**Prepare Cluster**](../cluster/prerequisite-tooling.md) and [**Deploy EOEPCA Components**](../eoepca/persistence.md). These sections should be consulted for more detailed information.

## Scripted Deployment

As a companion to these descriptions, we have developed a set of scripts to provide a demonstration of example deployments - see section [Scripted Deployment](scripted-deployment.md) for a detailed description of the scripts and how they are configured and used.

!!! note
    The scripted deployment assumes that installation of the [Prerequisite Tooling](../cluster/prerequisite-tooling.md) has been performed

## Customised Deployments

The Scripted Deployment can be quickly exploited through the following customisations (profiles) for particular use cases:

* **[Simple](simple-deployment.md)**<br>
  _Basic local deployment_
* **[Processing](processing-deployment.md)**<br>
  _Deployment focused on processing_
* **[Data Access](data-access-deployment.md)**<br>
  _Deployment focused on the Resource Catalogue and Data Access services_
* **[Exploitation](exploitation-deployment.md)**<br>
  _Deployment providing deployment/execution of processing via the ADES, supported by Resource Catalogue and Data Access services_
* **[User Management](userman-deployment.md)**<br>
  _Deployment focused on the Identity & Access Management services_
* **[Application Hub](application-hub-deployment.md)**<br>
  _Deployment providing the Application Hub that is pre-integrated via OIDC with the Identity Service_
* **[CREODIAS](creodias-deployment.md)**<br>
  _Deployment with access to CREODIAS EO data_

Each customisation is introduced in their respective sections.

## Quick Example

Follow these steps to create a [simple local deployment](simple-deployment.md) in minikube...

1. **Prerequisite Tooling**<br>
   Follow the steps in section [Prerequisite Tooling](../cluster/prerequisite-tooling.md) to install the required tooling.
2. **Clone the repository**<br>
   `git clone https://github.com/EOEPCA/deployment-guide`
3. **Initiate the deployment**<br>
   ```bash
   cd deployment-guide
   ./deploy/simple/simple
   ```
4. **Wait for deployment ready**<br>
     1. List pod status<br>
        `watch kubectl get pod -A`<br>
     1. Wait until all pods report either `Running` or `Completed`<br>
        _This may take 10-20 mins depending on the capabilities of your platform._
5. **Test the deployment**<br>
   Make the [sample requests](./processing-deployment.md#example-requests-snuggs-application) to the ADES processing service.
