# Data Specification

## Harvesting

The harvester is configured as follows...

```
harvester:
  image:
    repository: eoepca/rm-harvester
    tag: 1.1.0
  config:
    redis:
      host: data-access-redis-master
      port: 6379
    harvesters:
      - name: Creodias-Opensearch
        resource:
          url: https://finder.creodias.eu/resto/api/collections/Sentinel2/describe.xml
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
        queue: register_queue
```

Based upon this harvester configuration we expect that the following query is made to discover data...

```
https://finder.creodias.eu/resto/api/collections/Sentinel2/search.json?startDate=2019-09-10T00:00:00Z&completionDate=2019-09-11T00:00:00Z&box=14.9,47.7,16.4,48.7
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

> **QUESTION**<br>
> If we also wanted to harvest a different dataset, with a different post-processing need, would we instantiate a second harvester instance for this? Or is there another approach?

The harvester outputs a STAC item that includes this path to the Sentinel-2 scene, and is pushed to the registrar via the `register_queue` redis queue.

## Registration

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

Using this S3 configuration and the path to the Sentinel scene provided by the harvester in the STAC item, the registrar accesses the 'official' metadata XML. For example...

```
s3://EODATA/Sentinel-2/MSI/L1C/2019/09/10/S2B_MSIL1C_20190910T095029_N0208_R079_T33TXN_20190910T120910.SAFE/MTD_MSIL1C.xml
```

> **QUESTION**<br>
> How does the registrar know to access the file `MTD_MSIL1C.xml`?<br>
> It is understood that the registrar uses `stactools` library to read the Sentinel-2 scene metadata into STAC items - so maybe `stactools` handles the details of this. Does `stactools` auto-detect that this a Sentinel-2 to do this?<br>
> -> in which case, does this imply support for Sentinel-2 has been specifically built-in to the registrar container image?

The registrar uses this information to create the ISO XML metadata that is loaded into the resource-catalogue.

## Collections

The registrar (`eoepca/rm-data-access-core`) container image is pre-loaded with two collections at the path `/registrar_pycsw/registrar_pycsw/resources`:

* S2MSI1C.yml - identifier: `S2MSI1C`
* S2MSI2A.yml - identifier: `S2MSI2A`

> **QUESTION**<br>
> Since these are built-in to the container image - how to define different collections - or remove these if they are not required ?

> **QUESTION**<br>
> Further testing suggests that these `resources/*.yml` files that are built-in to the container image have no impact. The container image has been modified to:
> 
> 1. add an additional `resources/XXX.yml` file
> 1. delete the contents of the `resources/` directory.
> 
> In either case it made no difference to the outcome in which two collections `S2MSI1C` and `S2MSI2A` were created.

## Products

From the metadata XML file (e.g. `MTD_MSIL1C.xml`) the registrar obtains the _Product Type_ for each product from the field `<PRODUCT_TYPE>`...

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

The registrar uses the `product_type` of each product to determine the collection into which the product should be registered. The product is registered (using `parentidentifier`) into the collection whose `identifier` matches the `product_type`.

The product-to-collection matching is made using the `filter` definition of the `productType`, which appears to act as a 'selector' for the products - noting that the `name` of the product type does not take part in the matching logic (and hence can be any text name)...

```
  productTypes:
    - name: S2MSI1C
      filter:
        s2:product_type: S2MSI1C
```

> **QUESTION**<br>
> It is not clear to what the `s2:` prefix within the `s2:product_type` refers. To be clarified.

## Data Specification

The data-access helm defines `collections` and `productTypes` with bi-directional relationships established between then. The relationship must be expressed in both directions.

> **QUESTION**<br>
> It is not clear how these relate to:
> 
> * each other
> * the collections that are auto-registered into the catalogue during start-up of the registrar
> * the collections defined within the `rm-data-access-core` image (ref. files in `/registrar_pycsw/registrar_pycsw/resources`) - although these seem to be irrelevant anyway (see previous comment)
> * the `layers` that are also defined - there appears to be no direct cross-referencing to the `layers`

