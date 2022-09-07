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

The harvester post-processor follows this path to the Sentinel-2 scene and uses stactools (with built-in support for Sentinel-2) to establish a STAC item representing the product. This includes enumeration of `assets` for `inspire-metadata` and `product-metadata` - which are used by the registrar pycsw backend to embelesh the product record metadata.

The harvester outputs the STAC item for each product, which is pushed to the registrar via the `register_queue` redis queue.

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

Using this S3 configuration, the registrar pycsw backend uses the product metadata linked in the STAC item (ref. assets `inspire-metadata` and `product-metadata`) to embelesh the metadata. For example, `product-metadata` in the file...

```
s3://EODATA/Sentinel-2/MSI/L1C/2019/09/10/S2B_MSIL1C_20190910T095029_N0208_R079_T33TXN_20190910T120910.SAFE/MTD_MSIL1C.xml
```

The registrar uses this information to create the ISO XML metadata that is loaded into the resource-catalogue.

## Collections

The registrar (`eoepca/rm-data-access-core`) container image is pre-loaded with two collections at the path `/registrar_pycsw/registrar_pycsw/resources`, (in the built container the files are at the path `/usr/local/lib/python3.8/dist-packages/registrar_pycsw/resources/`):

* S2MSI1C.yml - identifier: `S2MSI1C`
* S2MSI2A.yml - identifier: `S2MSI2A`<br>

Products are mapped into these collecitons by the registrar using their _Product Type_ - i.e. they are mapped into the collections whose name matches the product type.

## Products

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

## Data Specification

The data-access helm defines `collections` and `productTypes` with bi-directional relationships established between then. The relationship must be expressed in both directions. A `layers` definition is also included to provide WMS layer definitions.

## `productType`

The registrar uses the `product_type` of each product to determine the collection into which the product should be registered. The product is registered (using `parentidentifier`) into the collection whose `identifier` matches the `product_type`.

The product-to-collection matching is made using the `filter` definition of the `productType`, which acts as a 'selector' for the products - noting that the `name` of the product type does not take part in the matching logic (and hence can be any text name)...

```
  productTypes:
    - name: S2MSI1C
      filter:
        s2:product_type: S2MSI1C
```

In the above example, the field `s2:product_type` is populated by the `stactools` that prepares the STAC item from the product metadata.

### `productType` - `coverages`

`coverages` defines the coverages for the WCS service. Each coverage links to the `assets` that are defined within the product STAC item.

### `productType` - `browses`

`browses` defines the images that are visualised in the View Server Client. Expressions are used to map the product assets into their visual representation.

## `collections`

Collections are defined by reference to the defined `productTypes` and `coverages`.

## `layers`

Layers are defined via their `id` that relies upon the naming convection `<collection>__<browse>` to define the layer.

