# CREODIAS Deployment

Based upon our development experiences on CREODIAS, there is a wrapper script [`creodias`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/creodias/creodias) with particular customisations suited to the [CREODIAS](https://creodias.eu/) infrastructure and data offering.

The customisations are expressed through [environment variables](scripted-deployment.md#environment-variables) that are captured in the file [`creodias-options`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/creodias/creodias-options).

With reference to the file `creodias-options`, particular attention is drawn to the following environment variables that require tailoring to your CREODIAS (Cloudferro) environment...

* `public_ip` - The public IP address through which the deployment is exposed via the ingress-controller
* `domain` - The DNS domain name through which the deployment is accessed - forming the stem for all service hostnames in the ingress rules
* Passwords: `LOGIN_SERVICE_ADMIN_PASSWORD`, `MINIO_ROOT_PASSWORD`, `HARBOR_ADMIN_PASSWORD`
* OpenStack details: see section [Openstack Configuration](#openstack-configuration)

Once the file `creodias-options` has been well populated for your environment, then the deployment is initiated with...
```bash
./deploy/creodias/creodias
```
...noting that this step is a customised version of that described in section [Deployment](scripted-deployment.md#deployment).

Similarly the script `creodias-protection` is a customised version of that described in section [Apply Protection](#apply-protection). Once the main deployment has completed, then the [test users can be created](#create-test-users), their IDs (`Inum`) set in script `creodias-protection`, and the resource protection can then be applied...

```bash
./deploy/creodias/creodias-protection
```

These scripts are examples that can be seen as a starting point, from which they can be adapted to your needs.

## Harvest CREODIAS Data

The example scripts include optional specifcation of data-access/harvesting configuration that is tailored for the CREODIAS data offering. This is controlled via the option `CREODIAS_DATA_SPECIFICATION=true` - see [Environment Variables](scripted-deployment.md#environment-variables). The harvester configuration specifies datasets with spatial/temporal extents, which is configured into the file `/config.yaml` of the `data-access-harvester` deployment.

As described in the [Data Access section](../eoepca/data-access.md#starting-the-harvester), harvesting according to this configuration can be triggered with...
```
kubectl -n rm exec -it deployment.apps/data-access-harvester -- python3 -m harvester harvest --config-file /config.yaml --host data-access-redis-master --port 6379 Creodias-Opensearch
```
