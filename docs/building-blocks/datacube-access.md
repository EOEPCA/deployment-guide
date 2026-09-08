# Datacube Access

The **Datacube Access** Building Block provides best practices for describing data with STAC metadata so that clients can load it into datacubes and publish processed results. There is no separate Datacube Access service or proxy to deploy.

## Metadata and data access

The [STAC Best Practices for Datacube Access](https://github.com/EOEPCA/datacube-access/blob/main/best_practices/stac_best_practices.md) describe how to represent spatial, temporal and band information for predictable loading and storage. They cover raster files such as GeoTIFF, datacube formats such as Zarr and netCDF, and other data types.

Use the STAC fields and extensions appropriate to the assets. Projection metadata must describe the actual asset grid; changing metadata does not reproject or crop the data. Where inputs have different coordinate systems or resolutions, the client must select a target grid and resampling strategy. Temporal aggregation and handling of overlapping observations also require explicit choices.

The Datacube extension describes dimensions and, where applicable, variables. It is not a requirement to add every extension to every collection or item. Follow the best practices for the relevant file format and check support in the intended client.

Metadata alone does not make assets accessible. Clients also need network access, any required credentials, and support for the referenced file formats.

## Deployment prerequisites

Deploy the services required by the chosen workflow:

| Building Block | Role |
| --- | --- |
| [Data Access](./data-access.md) | Serves the STAC API used to register and query collections and items. Enable transactions for registration through the API. |
| [Workspace](./workspace.md) | Stores prepared metadata and outputs in an S3-compatible bucket and provides a development environment. |
| [Identity and Access Management](./iam/main-iam.md) | Authenticates Workspace users and, when enabled for Data Access, controls STAC access. |
| [Resource Registration](./resource-registration.md) | Optional harvesting when registration is performed by a workflow rather than direct STAC transactions. |

A Python client using `pystac-client`, `odc-stac` and `xarray` can load and process data without a separate Processing deployment. Deploy a Processing backend when the workflow uses its API, such as openEO.

## Example workflow

1. Query an external STAC API for the required area and time interval.
2. Prepare and validate the collection and item metadata according to the best practices. Keep asset URLs pointing to the source data unless the assets are also copied or transformed.
3. Save the STAC JSON files in a Workspace bucket.
4. Register the collection and items with the Data Access STAC API, using a user authorised to write them. Saving JSON files in a bucket does not register them automatically.
5. Query the registered items with `pystac-client`, then load the referenced assets with `odc-stac` into an `xarray` dataset. Compute a small subset to verify that the asset reads succeed.
6. When publishing processed outputs, describe their actual grids, dimensions and bands, store the assets, and register the resulting metadata.

The [external data registration notebook]() illustrates this pattern with Sentinel-5P cloud fraction data. Adapt its service endpoints, identities and workspace name to the deployment.

## Verification

Check the workflow across service boundaries: authenticate, create a workspace, upload and retrieve a file using the workspace's storage credentials, register a small STAC collection and item, query the item through the public-facing STAC API, and read a small region of its raster asset.

For IAM-enabled Data Access, also verify that an unauthorised user cannot write the collection. See [Data Access collection-level access control](./data-access.md#4-collection-level-access-control-iam) for the required roles and ownership rules.

## Further reading

- [STAC Best Practices for Datacube Access](https://github.com/EOEPCA/datacube-access/blob/main/best_practices/stac_best_practices.md)
- [Datacube Access documentation](https://eoepca.readthedocs.io/projects/datacube-access/en/latest/)
- [STAC Datacube Extension](https://github.com/stac-extensions/datacube)
