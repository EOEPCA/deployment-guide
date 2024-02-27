# Data Access Deployment

## Overview

A deployment wrapper script has been prepared for a 'data access' deployment - that is focused on the Resource Catalogue and Data Access services.

The script [`deploy/data-access/data-access`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.3/deploy/data-access/data-access) achieves this by appropriate [configuration of the environment variables](scripted-deployment.md#environment-variables), before launching the [eoepca.sh deployment script](scripted-deployment.md#command-line-arguments). The deployment configuration is captured in the file [`deploy/data-access/data-access-options`](https://github.com/EOEPCA/deployment-guide/blob/eoepca-v1.3/deploy/data-access/data-access-options).

The data-access deployment applies the following configuration:

* Assumes a private deployment - i.e. no external-facing IP/ingress, and hence no TLS<br>
  _To configure an external-facing deployment with TLS protection, then see section [Public Deployment](scripted-deployment.md#public-deployment)_
* No TLS for service ingress endpoints
* Services deployed:
    * Resource Catalogue for data discovery
    * Data Access for data visualisation and download
* Includes data specification for CREODIAS Sentinel-2, which can be exploited if running in a CREODIAS VM connected to the `eodata` network - [see description of variable `CREODIAS_DATA_SPECIFICATION`](scripted-deployment.md#environment-variables)
* Open ingress are enabled for unauthenticated access to resource-catalogue and data-access services
* Other eoepca services not deployed

## Initiate Deployment

Deployment is initiated by invoking the script...

```
./deploy/data-access/data-access
```

The Resource Catalogue is accessed at the endpoint `resource-catalogue-open.<domain>` - e.g. [`resource-catalogue-open.192-168-49-2.nip.io`](http://resource-catalogue-open.192-168-49-2.nip.io/).

The Data Access View Server is accessed at the endpoint `data-access-open.<domain>` - e.g. [`data-access-open.192-168-49-2.nip.io`](http://data-access-open.192-168-49-2.nip.io/).

## Post-deploy Manual Steps

To complete the deployment, see section [Post-deployment Manual Steps](./scripted-deployment.md#post-deployment-manual-steps) of the [Scripted Deployment](./scripted-deployment.md) page.

## Data Harvesting

See section [Harvest CREODIAS Data](creodias-deployment.md#harvest-creodias-data) to harvest the default data specification from the CREODIAS data offering.
