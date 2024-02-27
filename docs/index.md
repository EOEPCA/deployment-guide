# Deployment Guide

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
