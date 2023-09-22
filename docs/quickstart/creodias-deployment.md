# CREODIAS Deployment

Based upon our development experiences on CREODIAS, there is a wrapper script [`creodias`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/creodias/creodias) with particular customisations suited to the [CREODIAS](https://creodias.eu/) infrastructure and data offering. The customisations are expressed through [environment variables](scripted-deployment.md#environment-variables) that are captured in the file [`creodias-options`](https://github.com/EOEPCA/deployment-guide/blob/main/deploy/creodias/creodias-options).

These scripts are examples that can be seen as a starting point, from which they can be adapted to your needs.

The CREODIAS deployment applies the following configuration:

* Assumes a private deployment - i.e. no external-facing IP/ingress, and hence no TLS<br>
  _To configure an external-facing deployment with TLS protection, then see section [Public Deployment](scripted-deployment.md#public-deployment)_
* No TLS for service ingress endpoints
* Protected service endpoints requiring IAM authorization<br>
  _See [Endpoint Protection](#endpoint-protection) below for further information_

With reference to the file `creodias-options`, particular attention is drawn to the following environment variables that require tailoring to your CREODIAS (Cloudferro) environment...

* Passwords: `LOGIN_SERVICE_ADMIN_PASSWORD`, `MINIO_ROOT_PASSWORD`, `HARBOR_ADMIN_PASSWORD`
* OpenStack details: see section [Openstack Configuration](scripted-deployment.md#openstack-configuration)
* If configuring an external deployment - ref. [Public Deployment](scripted-deployment.md#public-deployment)...
    * `public_ip` - The public IP address through which the deployment is exposed via the ingress-controller
    * `domain` - The DNS domain name through which the deployment is accessed - forming the stem for all service hostnames in the ingress rules

Once the file `creodias-options` has been well populated for your environment, then the deployment is initiated with...
```bash
./deploy/creodias/creodias
```
...noting that this step is a customised version of that described in section [Deployment](scripted-deployment.md#deployment).

## Endpoint Protection

Similarly the script `creodias-protection` is a customised version of that described in section [Apply Protection](scripted-deployment.md#apply-protection). Once the main deployment has completed, then the [test users can be created](scripted-deployment.md#create-test-users), their IDs (`Inum`) set in script `creodias-protection`, and the resource protection can then be applied...

```bash
./deploy/creodias/creodias-protection
```

## Harvest CREODIAS Data

The harvester can be [deployed with a default configuration](../eoepca/data-access.md#harvester-helm-configuration) file at `/config.yaml`. As described in the [Data Access section](../eoepca/data-access.md#starting-the-harvester), harvesting according to this configuration can be triggered with...
```
kubectl -n rm exec -it deployment.apps/data-access-harvester -- python3 -m harvester harvest --config-file /config.yaml --host data-access-redis-master --port 6379 Creodias-Opensearch
```

See the [Harvester](#harvester) section below for an explanation of this harvester configuration.

## Data Specification Walkthrough

The example scripts include optional specifcation of data-access/harvesting configuration that is tailored for the CREODIAS data offering. This is controlled via the option `CREODIAS_DATA_SPECIFICATION=true` - see [Environment Variables](scripted-deployment.md#environment-variables).

This section provides a walkthrough of this configuration for CREODIAS - to act as an aid to understanding by way of a worked example.

### Harvester

The harvester configuration specifies datasets with spatial/temporal extents, which is configured into the file `/config.yaml` of the `data-access-harvester` deployment.

The harvester is configured as follows...

```
harvester:
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 100Mi
  config:
    redis:
      host: data-access-redis-master
      port: 6379
    harvesters:
      - name: Creodias-Opensearch
        resource:
          url: https://datahub.creodias.eu/resto/api/collections/Sentinel2/describe.xml
          type: OpenSearch
          format_config:
            type: 'application/json'
            property_mapping:
              start_datetime: 'startDate'
              end_datetime: 'completionDate'
              productIdentifier: 'productIdentifier'
          query:
            time:
              property: sensed
              begin: 2019-09-10T00:00:00Z
              end: 2019-09-11T00:00:00Z
            collection: null
            bbox: 14.9,47.7,16.4,48.7
        filter: {}
        postprocess:
          - type: harvester_eoepca.postprocess.CREODIASOpenSearchSentinel2Postprocessor
        queue: register
      - name: Creodias-Opensearch-Sentinel1
        resource:
          url: https://datahub.creodias.eu/resto/api/collections/Sentinel1/describe.xml
          type: OpenSearch
          format_config:
            type: 'application/json'
            property_mapping:
              start_datetime: 'startDate'
              end_datetime: 'completionDate'
              productIdentifier: 'productIdentifier'
          query:
            time:
              property: sensed
              begin: 2019-09-10T00:00:00Z
              end: 2019-09-11T00:00:00Z
            collection: null
            bbox: 14.9,47.7,16.4,48.7
            extra_params:
              productType: GRD-COG
        filter: {}
        postprocess:
          - type: harvester_eoepca.postprocess.CREODIASOpenSearchSentinel1Postprocessor
        queue: register
```

Based upon this harvester configuration we expect that the following query is made to discover data - i.e. an OpenSearch query, with json response representation, for a defined spatial and temporal extent...

```
https://datahub.creodias.eu/resto/api/collections/Sentinel2/search.json?startDate=2019-09-10T00:00:00Z&completionDate=2019-09-11T00:00:00Z&box=14.9,47.7,16.4,48.7
```

From the result returned, the path to each product (`feature`) is obtained from the `productIdentifier` property, e.g.

```
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "productIdentifier": "/eodata/Sentinel-2/MSI/L1C/2019/09/10/S2B_MSIL1C_20190910T095029_N0208_R079_T33TXN_20190910T120910.SAFE"
        ...
      }
      ...
    }
    ...
  ]
}
```

The harvester is configured with a Sentinel-2/CREODIAS specific post-processor `harvester_eoepca.postprocess.CREODIASOpenSearchSentinel2Postprocessor` which transforms the product path from `/eodata/...` to `s3://EODATA/...`.

The harvester post-processor follows this path to the Sentinel-2 scene and uses stactools (with built-in support for Sentinel-2) to establish a STAC item representing the product. This includes enumeration of `assets` for `inspire-metadata` and `product-metadata` - which are used by the registrar pycsw backend to embelesh the product record metadata.

!!! note
    The above description considers Sentinel-2 data. Similar considerations apply for Sentinel-1 that is also detailed in the above harvester configuration.

The harvester outputs the STAC item for each product, which is pushed to the registrar via the `register` redis queue.

### Registration

The registrar is configured at deployment to have the access details for the CREODIAS data in S3...

```
global:
  storage:
    data:
      data:
        type: S3
        endpoint_url: http://data.cloudferro.com
        access_key_id: access
        secret_access_key: access
        region_name: RegionOne
        validate_bucket_name: false
```

Using this S3 configuration, the registrar pycsw backend uses the product metadata linked in the STAC item (ref. assets `inspire-metadata` and `product-metadata`) to embelesh the metadata. For example, `product-metadata` in the file...

```
s3://EODATA/Sentinel-2/MSI/L1C/2019/09/10/S2B_MSIL1C_20190910T095029_N0208_R079_T33TXN_20190910T120910.SAFE/MTD_MSIL1C.xml
```

The registrar uses this information to create the ISO XML metadata that is loaded into the resource-catalogue.

### Product Type

The registrar recognises the product as Sentinel-2 and so reads its metadata XML files to obtain additional information. From the metadata XML file (e.g. `MTD_MSIL1C.xml`) the registrar obtains the _Product Type_ for each product from the field `<PRODUCT_TYPE>`...

```
<n1:Level-1C_User_Product>
  <n1:General_Info>
    <Product_Info>
      <PRODUCT_TYPE>S2MSI1C</PRODUCT_TYPE>
      ...
    </Product_Info>
    ...
  </n1:General_Info>
  ...
<n1:Level-1C_User_Product>
```

### Resource Catalogue Collections

The registrar (`eoepca/rm-data-access-core`) container image is pre-loaded with two collections at the path `/registrar_pycsw/registrar_pycsw/resources`, (in the built container the files are at the path `/usr/local/lib/python3.8/dist-packages/registrar_pycsw/resources/`):

* S2MSI1C.yml - identifier: `S2MSI1C`
* S2MSI2A.yml - identifier: `S2MSI2A`

The registrar applies these collections into the resource-catalogue during start-up - to create pre-defined out-of-the-box collections in pycsw.

During registration, the `PycswBackend` of the registrar uses the _Product Type_ to map the product into the collection of the same name - using metadata field `parentidentifier`.

### Data Specification

The data-access service data handling is configured by definition of `productTypes`, `collections` and `layers`...

* `productTypes` identify the underlying file assets as WCS coverages and their visual representation
* `collections` provide groupings into which products are organised
* `layers` specifies the hoe the product visual representations are exposed through the WMS service

#### `productType`

During registration, products are mapped into a `productType` via a `filter` that is applied against the STAC item metadata.

The registrar uses the `product_type` of each product to determine the `collection` into which the product should be registered - noting that the `name` of the product type does not take part in the matching logic (and hence can be any text name)...

```
  productTypes:
    - name: S2MSI1C
      filter:
        s2:product_type: S2MSI1C
```

In the above example, the field `s2:product_type` is populated by the `stactools` that prepares the STAC item from the product metadata.

##### `productType` - `coverages`

`coverages` defines the coverages for the WCS service. Each coverage links to the `assets` that are defined within the product STAC item.

##### `productType` - `browses`

`browses` defines the images that are visualised in the View Server Client. Expressions are used to map the product assets into their visual representation.

#### `collections`

Collections are defined by reference to the defined `productTypes` and `coverages`.

#### `layers`

`layers` defines the layers that are presented through the WMS service - each layer being linked to the underlying `browse` that provides the image source. Layers are defined via their `id` that relies upon the naming convection `<collection>__<browse>` to identify the browse and so define the layer.

#### Example Configuration

Example configuration for Sentinel-2 L1C and L2A data.

```yaml
global:
  layers:
    - id: S2L1C
      title: Sentinel-2 Level 1C True Color
      abstract: Sentinel-2 Level 2A True Color
      displayColor: '#eb3700'
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L1C__TRUE_COLOR
      title: Sentinel-2 Level 1C True Color
      abstract: Sentinel-2 Level 2A True Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L1C__masked_clouds
      title: Sentinel-2 Level 1C True Color with cloud masks
      abstract: Sentinel-2 Level 1C True Color with cloud masks
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L1C__FALSE_COLOR
      title: Sentinel-2 Level 1C False Color
      abstract: Sentinel-2 Level 1C False Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L1C__NDVI
      title: Sentinel-2 Level 21CNDVI
      abstract: Sentinel-2 Level 1C NDVI
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L1C
    - id: S2L2A
      title: Sentinel-2 Level 2A True Color
      abstract: Sentinel-2 Level 2A True Color
      displayColor: '#eb3700'
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
    - id: S2L2A__TRUE_COLOR
      title: Sentinel-2 Level 2A True Color
      abstract: Sentinel-2 Level 2A True Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
    - id: S2L2A__masked_clouds
      title: Sentinel-2 Level 2A True Color with cloud masks
      abstract: Sentinel-2 Level 2A True Color with cloud masks
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
    - id: S2L2A__FALSE_COLOR
      title: Sentinel-2 Level 2A False Color
      abstract: Sentinel-2 Level 2A False Color
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
    - id: S2L2A__NDVI
      title: Sentinel-2 Level 2A NDVI
      abstract: Sentinel-2 Level 2A NDVI
      grids:
        - name: WGS84
          zoom: 13
      parentLayer: S2L2A
  collections:
    S2L1C:
      product_types:
        - S2MSI1C
      coverage_types:
        - S2L1C_B01
        - S2L1C_B02
        - S2L1C_B03
        - S2L1C_B04
        - S2L1C_B05
        - S2L1C_B06
        - S2L1C_B07
        - S2L1C_B08
        - S2L1C_B8A
        - S2L1C_B09
        - S2L1C_B10
        - S2L1C_B11
        - S2L1C_B12
    S2L2A:
      product_types:
        - S2MSI2A
      product_levels:
        - Level-2A
      coverage_types:
        - S2L2A_B01
        - S2L2A_B02
        - S2L2A_B03
        - S2L2A_B04
        - S2L2A_B05
        - S2L2A_B06
        - S2L2A_B07
        - S2L2A_B08
        - S2L2A_B8A
        - S2L2A_B09
        - S2L2A_B11
        - S2L2A_B12
  productTypes:
    - name: S2MSI1C
      filter:
        s2:product_type: S2MSI1C
      metadata_assets: []
      coverages:
        S2L1C_B01:
          assets:
            - B01
        S2L1C_B02:
          assets:
            - B02
        S2L1C_B03:
          assets:
            - B03
        S2L1C_B04:
          assets:
            - B04
        S2L1C_B05:
          assets:
            - B05
        S2L1C_B06:
          assets:
            - B06
        S2L1C_B07:
          assets:
            - B07
        S2L1C_B08:
          assets:
            - B08
        S2L1C_B8A:
          assets:
            - B8A
        S2L1C_B09:
          assets:
            - B09
        S2L1C_B10:
          assets:
            - B10
        S2L1C_B11:
          assets:
            - B11
        S2L1C_B12:
          assets:
            - B12
      defaultBrowse: TRUE_COLOR
      browses:
        TRUE_COLOR:
          asset: visual
          red:
            expression: B04
            range: [0, 4000]
            nodata: 0
          green:
            expression: B03
            range: [0, 4000]
            nodata: 0
          blue:
            expression: B02
            range: [0, 4000]
            nodata: 0
        FALSE_COLOR:
          red:
            expression: B08
            range: [0, 4000]
            nodata: 0
          green:
            expression: B04
            range: [0, 4000]
            nodata: 0
          blue:
            expression: B03
            range: [0, 4000]
            nodata: 0
        NDVI:
          grey:
            expression: (B08-B04)/(B08+B04)
            range: [-1, 1]
      masks:
        clouds:
          validity: false
    - name: S2MSI2A
      filter:
        s2:product_type: S2MSI2A
      metadata_assets: []
      coverages:
        S2L2A_B01:
          assets:
            - B01
        S2L2A_B02:
          assets:
            - B02
        S2L2A_B03:
          assets:
            - B03
        S2L2A_B04:
          assets:
            - B04
        S2L2A_B05:
          assets:
            - B05
        S2L2A_B06:
          assets:
            - B06
        S2L2A_B07:
          assets:
            - B07
        S2L2A_B08:
          assets:
            - B08
        S2L2A_B8A:
          assets:
            - B8A
        S2L2A_B09:
          assets:
            - B09
        S2L2A_B11:
          assets:
            - B11
        S2L2A_B12:
          assets:
            - B12
      default_browse_locator: TCI_10m
      browses:
        TRUE_COLOR:
          asset: visual-10m
          red:
            expression: B04
            range: [0, 4000]
            nodata: 0
          green:
            expression: B03
            range: [0, 4000]
            nodata: 0
          blue:
            expression: B02
            range: [0, 4000]
            nodata: 0
        FALSE_COLOR:
          red:
            expression: B08
            range: [0, 4000]
            nodata: 0
          green:
            expression: B04
            range: [0, 4000]
            nodata: 0
          blue:
            expression: B03
            range: [0, 4000]
            nodata: 0
        NDVI:
          grey:
            expression: (B08-B04)/(B08+B04)
            range: [-1, 1]
      masks:
        clouds:
          validity: false
```

