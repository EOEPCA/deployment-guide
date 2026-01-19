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

## Installation

### Basic Installation

```bash
pip install eodag
```

### Installation with STAC Server Support

To enable STAC REST API functionality:

```bash
pip install eodag[server]
```

### Verify Installation

```bash
eodag version
eodag --help
```

---

## Configuration

### Initial Setup

The first time EODAG runs, it creates a configuration file at `~/.config/eodag/eodag.yml`. Trigger this by running:

```bash
eodag list --no-fetch | head -5
```

### Configure Provider Credentials

Edit `~/.config/eodag/eodag.yml` to add your provider credentials:

```yaml
cop_dataspace:
  priority: 2
  download:
    extract: False
    outputs_prefix: /home/user/eodata/
  auth:
    credentials:
      username: your_username
      password: your_password
```

Key configuration options:
- **priority**: Higher values mean the provider is tried first (default: 1)
- **extract**: Whether to automatically extract downloaded archives (default: True)
- **outputs_prefix**: Directory for downloaded products (default: system temp directory)

---

## Usage: Command Line Interface

### List Available Product Types

```bash
# List all product types (without fetching remote catalogues)
eodag list --no-fetch

# Filter by provider
eodag list --provider cop_dataspace --no-fetch

# Filter by platform
eodag list --platform SENTINEL2 --no-fetch

# Filter by sensor type
eodag list --sensorType OPTICAL --no-fetch
```

### Search for Products

```bash
# Basic search
eodag search \
  --productType S2_MSI_L1C \
  --box 1 43 2 44 \
  --start 2024-01-01 \
  --end 2024-01-15

# Search with cloud cover filter
eodag search \
  --productType S2_MSI_L1C \
  --box 1 43 2 44 \
  --start 2024-06-01 \
  --end 2024-06-30 \
  --cloudCover 20 \
  --storage low_cloud_results.geojson

# Get all matching results (not just first page)
eodag search \
  --productType S2_MSI_L1C \
  --box 1 43 2 44 \
  --start 2024-01-01 \
  --end 2024-01-05 \
  --all
```

### Download Products

```bash
eodag download --search-results search_results.geojson
```

### Discover New Product Types

```bash
eodag discover -p earth_search --storage /tmp/earth_search_products.json
```

---

## Usage: Python API

```python
from eodag import EODataAccessGateway

# Initialise EODAG
dag = EODataAccessGateway()

# List available providers
providers = dag.available_providers()
print(f"Found {len(providers)} providers")

# Search for Sentinel-2 products
results = dag.search(
    productType="S2_MSI_L1C",
    geom={'lonmin': 1, 'latmin': 43.5, 'lonmax': 2, 'latmax': 44},
    start='2024-01-01',
    end='2024-01-15',
    provider='earth_search',  # Optional: specify provider
    items_per_page=10
)

print(f"Found {len(results)} products")

# Inspect a product
if results:
    product = results[0]
    print(f"ID: {product.properties.get('id')}")
    print(f"Cloud cover: {product.properties.get('cloudCover'):.1f}%")

# Download all results
product_paths = dag.download_all(results)

# Or download a specific product
if results:
    path = dag.download(results[0])
    print(f"Downloaded to: {path}")
```

### Search with Cloud Cover Filter

```python
results = dag.search(
    productType="S2_MSI_L1C",
    geom={"lonmin": 1, "latmin": 43, "lonmax": 2, "latmax": 44},
    start="2024-06-01",
    end="2024-06-30",
    cloudCover=20,
    items_per_page=5
)
```

### Search with WKT Geometry

```python
wkt = "POLYGON((1 43, 2 43, 2 44, 1 44, 1 43))"
results = dag.search(
    productType="S2_MSI_L1C",
    geom=wkt,
    start="2024-01-01",
    end="2024-01-05"
)
```

---

## STAC Server Mode

> **Note**: The `serve-rest` command is deprecated since EODAG v3.9.0 and will be removed in a future version. For production deployments, use [stac-fastapi-eodag](https://github.com/CS-SI/stac-fastapi-eodag). The built-in server remains functional for development and testing.

### Start the STAC Server

```bash
eodag serve-rest --world --port 5000
```

### Query the STAC API

```bash
# Root endpoint
curl -s http://localhost:5000 | jq .

# List all collections
curl -s "http://localhost:5000/collections" | jq .

# Filter collections by provider
curl -s "http://localhost:5000/collections?provider=earth_search" | jq .

# Search for products
curl -s "http://localhost:5000/search?collections=S2_MSI_L1C&bbox=1,43,2,44&datetime=2024-01-01/2024-01-15&limit=5" | jq .
```

---

## Supported Providers

EODAG comes pre-configured with many providers including:
- **cop_dataspace**: Copernicus Data Space Ecosystem
- **earth_search**: Element 84's Earth Search on AWS
- **planetary_computer**: Microsoft Planetary Computer
- **usgs_satapi_aws**: USGS via AWS
- **creodias**: CREODIAS platform
- **dedl**: Destination Earth Data Lake

View available providers in Python:

```python
dag = EODataAccessGateway()
print(dag.available_providers())
```

See the complete list in the [EODAG Providers Documentation](https://eodag.readthedocs.io/en/stable/providers.html).

---

## Extending EODAG with Custom Providers

You can add custom providers either via the YAML configuration file or programmatically.

### Method 1: YAML Configuration

Add to `~/.config/eodag/eodag.yml`:

```yaml
my_custom_stac_provider:
  search:
    type: StacSearch
    api_endpoint: https://my-stac-api.example.com/search
    need_auth: false
  products:
    GENERIC_PRODUCT_TYPE:
      productType: '{productType}'
  download:
    type: HTTPDownload
```

### Method 2: Python API

```python
from eodag import EODataAccessGateway

dag = EODataAccessGateway()

# Using add_provider() for simple STAC providers
dag.add_provider(
    name="my_stac_provider",
    url="https://my-stac-api.example.com/search"
)

# Or using update_providers_config() for more control
dag.update_providers_config("""
my_custom_provider:
  search:
    type: StacSearch
    api_endpoint: https://my-stac-api.example.com/search
    need_auth: false
  products:
    GENERIC_PRODUCT_TYPE:
      productType: '{productType}'
  download:
    type: HTTPDownload
""")

# Set as preferred provider
dag.set_preferred_provider("my_custom_provider")

# Now search using the custom provider
results = dag.search(
    productType="sentinel-2-l2a",
    start="2024-01-01",
    end="2024-01-15"
)
```

---

## Further Resources

- **[EODAG Documentation](https://eodag.readthedocs.io/)** - Comprehensive guide and API reference
- **[EODAG GitHub Repository](https://github.com/CS-SI/eodag)** - Source code and examples
- **[EOEPCA Data Gateway Architecture](https://eoepca.readthedocs.io/projects/architecture/en/latest/reference-architecture/data-gateway-BB/)** - Architectural design and integration patterns
- **[stac-fastapi-eodag](https://github.com/CS-SI/stac-fastapi-eodag)** - Production STAC server implementation
- **[EODAG JupyterLab Extension](https://github.com/CS-SI/eodag-labextension)** - GUI for searching and browsing EO products
- **[Provider Configuration Guide](https://eodag.readthedocs.io/en/stable/getting_started_guide/configure.html)** - Detailed provider setup instructions