# Datacube Access Deployment Guide

The **Datacube Access** Building Block defines a metadata convention - STAC Best Practices for Data Cubes - that lets data move between other Building Blocks as analysis-ready cubes. It has no service of its own to deploy: it's a set of conventions applied wherever you register STAC metadata into the platform.

---

## Introduction

Data Access, Workspace, Resource Registration and Processing (openEO / OGC API Processes) already move data between each other. What none of them can infer on its own is whether a STAC collection is actually structured as a *datacube* - consistent geometry and CRS across items, band and dimension metadata a tool like `odc-stac` or openEO can parse without guesswork. Datacube Access closes that gap: a metadata convention, built on the [STAC Datacube Extension](https://github.com/stac-extensions/datacube) plus the `projection`, `raster` and `eo` extensions, that any Building Block can rely on once a collection follows it.

See the [STAC Best Practices for Data Cubes](https://github.com/EOEPCA/datacube-access/blob/main/best_practices/stac_best_practices.md) for the full convention, and the [Design Overview](https://eoepca.readthedocs.io/projects/datacube-access/en/latest/design/overview/) for how this BB relates to the others.

### End-to-End Workflow

This is the pattern the other Building Blocks are used together to implement:

1. **Get external data** - ingest a STAC collection from wherever it originates: a third-party STAC API, a Processing output, a raw dataset.
2. **Apply STAC Best Practices** - reshape the collection and item metadata to the convention: consistent geometry, shape and CRS across items, plus the `datacube`, `projection`, `raster` and `eo` extensions describing the cube's dimensions and bands.
3. **Save metadata** - upload the prepared STAC files and data assets to a workspace ([Workspace](./workspace.md) BB), so they're accessible to other users and Building Blocks.
4. **Register to the STAC API** - publish the collection into the platform's catalog: directly via [Data Access](./data-access.md)'s `eoapi` transaction endpoint, or through a [Resource Registration](./resource-registration.md) harvester workflow for repeatable ingestion.
5. **Access and process** - any STAC-aware client - `pystac-client` + `odc-stac`, or openEO/Processing - can now load the collection as an analysis-ready cube straight from that STAC API, because the metadata already carries the structure needed.
6. **Register the results** - publish processed outputs back to the STAC API the same way, so they're findable and reusable by the next consumer.

---

## Usage and Testing

### Prerequisites

- [Data Access](./data-access.md) BB deployed, with its `eoapi` STAC API reachable.
- `kubectl` configured for cluster access (the test fixture below loads data via `pypgstac` inside the `eoapi-raster` pod).

**Clone the Deployment Guide Repository:**

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/datacube-access
```

### Loading a Test Collection

Add a sample datacube-ready collection to your STAC catalog. There is a provided script in the `collections/datacube-ready-collection/` directory. This loads directly into the `eoapi` component of the Data Access BB via `pypgstac`, using the `collections.json` and `items.json` provided.

```bash
cd collections/datacube-ready-collection
../ingest.sh
cd ../..
```

View the collection at
```
https://eoapi.${INGRESS_HOST}/stac/collections/sentinel-2-datacube
```

### Testing with Processing Tools

A test script is provided to demonstrate loading the datacube using Python libraries like `pystac-client` and `odc-stac`. It searches the Data Access BB's STAC API for the test collection above and loads it into an `xarray` datacube.

```bash
cd tests
python -m venv venv
source ./venv/bin/activate
pip install -U -r requirements.txt
source ~/.eoepca/state
python processing-tools.py
deactivate
cd ..
```

### Relevance to OpenEO

[openEO](https://openeo.org/) backends need exact band names, temporal resolution and dimension relationships to build a process graph - e.g. an NDVI time series workflow. A collection that follows the STAC Best Practices convention carries that metadata regardless of which STAC endpoint serves it, so openEO/Processing can load it reliably straight from the Data Access BB's STAC API.

---

## Further Reading & Official Docs

- [STAC Best Practices for Data Cubes](https://github.com/EOEPCA/datacube-access/blob/main/best_practices/stac_best_practices.md) - the metadata convention this BB defines
- [EOEPCA Datacube Access Documentation](https://eoepca.readthedocs.io/projects/datacube-access/en/latest/)
- [OGC GeoDataCube API](https://m-mohr.github.io/geodatacube-api/)
- [STAC Datacube Extension](https://github.com/stac-extensions/datacube)
- [openEO Documentation](https://openeo.org/documentation/1.0/)
