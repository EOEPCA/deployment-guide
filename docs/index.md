# Deployment Guide

!!! ChangeLog
    
    This `current` version of the Deployment Guide represents the development tip that goes beyond the [latest release verion v1.4](../v1.4).

    The following provides a summary of changes since the last release (v1.4)...
    
    * **[FIX]** Update Application Hub to chart version `2.0.57` to fix hard-coded ingress namespace
    * **[FIX]** Correct default value of `PROCESSING_MAX_RAM` to the integer value in Mi `8192` (was string `8Gi`)

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
