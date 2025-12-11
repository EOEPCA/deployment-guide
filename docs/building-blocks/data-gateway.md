# Data Gateway Building Block

## Introduction

The Data Gateway Building Block provides a consolidated and consistent capability for accessing Earth Observation data from an extensible set of providers and datasets. Unlike other EOEPCA building blocks that require deployment, the Data Gateway is implemented through **EODAG** (Earth Observation Data Access Gateway) - a Python library and command-line tool that other components integrate directly.

---

## Architecture

The Data Gateway acts as an abstraction layer between EOEPCA components and various data providers. It presents a unified interface (including STAC semantics) regardless of the underlying data source, eliminating the need for each building block to implement provider-specific logic.

**Key Capabilities:**
- Unified API for 50+ product types across 10+ providers
- Plugin architecture supporting STAC, OpenSearch, OData, and custom protocols
- Automatic handling of authentication and data retrieval
- Extensible to support new providers via configuration or plugins

---

## Integration with EOEPCA

The Data Gateway is utilised by other building blocks rather than deployed standalone:

- **Resource Registration**: Uses Data Gateway for harvesting from external catalogues
- **Processing Engine**: Leverages it for input data preparation and access
- **Data Access**: Employs it for retrieving dataset assets for visualisation services

---

## Configuration

### Basic Setup

1. **Install EODAG**:
```bash
pip install eodag
```

2. **Configure Provider Credentials**:

EODAG automatically creates a configuration file at `~/.config/eodag/eodag.yml` on first run. Add your provider credentials:

```yaml
providers:
  cop_dataspace:
    auth:
      credentials:
        username: your_username
        password: your_password
```

---

## Usage Example

### Python Integration

```python
from eodag import EODataAccessGateway

# Initialise EODAG
dag = EODataAccessGateway()

# Search for Sentinel-2 products
search_results = dag.search(
    collection='S2_MSI_L1C',
    geom={'lonmin': 1, 'latmin': 43.5, 'lonmax': 2, 'latmax': 44},
    start='2021-01-01',
    end='2021-01-15',
    provider='cop_dataspace'  # Optional: specify provider
)

# Download all results
product_paths = dag.download_all(search_results)

# Or download specific item
if search_results:
    first_product = search_results[0]
    path = dag.download(first_product)
    print(f"Downloaded to: {path}")
```

### Command Line Interface

```bash
# List available product types
eodag list

# Search for products
eodag search --productType S2_MSI_L1C \
  --box 1 43 2 44 \
  --start 2021-01-01 --end 2021-01-15

# Download search results
eodag download --search-results search_results.geojson
```

---

## Supported Providers

EODAG comes pre-configured with many providers including:
- Copernicus Data Space
- AWS/GCS (Sentinel on cloud storage)
- CREODIAS, Mundi, ONDA, WEkEO (DIAS platforms)
- USGS (Landsat products)
- Destination Earth Data Lake

View the complete list and their configurations in the [EODAG Providers Documentation](https://eodag.readthedocs.io/en/stable/providers.html).

---

## Extending EODAG

Add custom providers by creating a configuration:

```yaml
my_custom_provider:
  search:
    type: StacSearch
    api_endpoint: https://my-stac-api.com
  products:
    S2_L2A:
      productType: sentinel-2-l2a
```

---

## Further Resources

- **[EODAG Documentation](https://eodag.readthedocs.io/)** - Comprehensive guide and API reference
- **[EODAG GitHub Repository](https://github.com/CS-SI/eodag)** - Source code and examples
- **[EOEPCA Data Gateway Architecture](https://eoepca.readthedocs.io/projects/architecture/en/latest/reference-architecture/data-gateway-BB/)** - Architectural design and integration patterns
- **[EODAG JupyterLab Extension](https://github.com/CS-SI/eodag-labextension)** - GUI for searching and browsing EO products
- **[Provider Configuration Guide](https://eodag.readthedocs.io/en/stable/getting_started_guide/configure.html)** - Detailed provider setup instructions
