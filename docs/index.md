# Deployment Guide

!!! ChangeLog
    
    This `current` version of the Deployment Guide represents the development tip that goes beyond the [latest release version v1.4](../v1.4).

    The following provides a summary of changes since the last release (v1.4)...

    * **03/04/2024** - Update Identity Gatekeeper to chart version `1.0.12` with an alternative approach to establishing 'open' access to select request paths (e.g. for docs etc.), to simplify proxying to the backend resource server.
    * **03/04/2024** - Update Data Access to chart `1.4.1` to introduce variables to remedy hard-coded harvester values for access to Creodias eodata. Ref. - `CREODIAS_EODATA_S3_ENDPOINT`, `CREODIAS_EODATA_S3_ACCESS_KEY`, `CREODIAS_EODATA_S3_ACCESS_SECRET` and `CREODIAS_EODATA_S3_REGION`.
    * **20/03/2024** - Correction to chart path for helm deployment of `eoepca-portal`
    * **20/03/2024** - Correct hardcoded OAuth client secret for Application Hub
    * **20/03/2024** - Clarify Gatekeeper encryption key must be 16 or 32 characters long
    * **19/03/2024** - ADES stage-out fix (partial) for cwl workflow outputs of type Directory[] - e.g. `snuggs` sample app
    * **15/03/2024** - Update Application Hub to chart version `2.0.59` to add support for path-prefix (`BASE_URL`)
    * **08/03/2024** - Update Application Hub to chart version `2.0.58` to fix hard-coded namespace `proc`<br>
      _Namespace can now be set via chart environment variable `APP_HUB_NAMESPACE`_
    * **01/03/2024** - Adjust default Calrissian pod resource limits to 1024 Mi RAM, 2 vCPU
    * **01/03/2024** - Correct default value of `PROCESSING_MAX_RAM` to the integer value in Mi `1024` (was string `8Gi`)

The Deployment Guide captures each release of the EOEPCA Reference Implementation, by providing for each version...

* Description of how each building-block is configured and deployed - see **Deploy EOEPCA Components**
* Scripted deployment in which each building-block can be selectively deployed to form a system - see **Getting Started**

A full system deployment is described, in which components are deployed with complementary configurations that facilitate their integration as a coherent system. Nevertheless, each component can be cherry-picked from this system deployment for individual re-use.

The deployment is organised into the following sections:

* **Getting Started**<br>
  A quickstart guide with associated scripts to facilitate example deployments, which preempt the descriptions that follow later in the document.<br>
  Scripts are provided in a variety of 'profiles' that deploy different combinations of building-blocks for different notional use cases.
* **Prepare Cluster**<br>
  Establish the Kubernetes cluster and other prerequisites for the deployment of the EOEPCA system.
* **Deploy EOEPCA Components**<br>
  Deployment of the EOEPCA components.
