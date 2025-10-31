#!/usr/bin/env python3
# datacube access demo

import os
import warnings
import requests
from pystac_client import Client
from odc.stac import stac_load

# supress the warnings
warnings.filterwarnings('ignore', category=FutureWarning)
warnings.filterwarnings('ignore', category=UserWarning)

INGRESS_HOST = os.getenv("INGRESS_HOST", "example.com")
DATACUBE_ACCESS_URL = f"https://datacube-access.{INGRESS_HOST}"

print(f"Datacube acess demo")
print(f"URL: {DATACUBE_ACCESS_URL}\n")

# get the datacube collections
response = requests.get(f"{DATACUBE_ACCESS_URL}/collections")
response.raise_for_status()

collections_data = response.json()
collections = collections_data["collections"]

print(f"Found {len(collections)} datacube collection(s):")
for col in collections:
    print(f"  - {col['id']}")

# find stac api endpoint
stac_url = None
for link in collections_data.get("links", []):
    if link.get("rel") == "root":
        stac_url = link.get("href")
        break

print(f"\nSTAC API: {stac_url}")

# search for sentinel 2 data
catalog = Client.open(stac_url)
print("\nSearching region...")

items = catalog.search(
    collections=["sentinel-2-l2a-datacube"],
    bbox=[-34.2, 39.65, -32.88, 41.55],
    datetime="2025-10-30/2025-10-31"
).item_collection()

print(f"Found {len(items)} items")

if len(items) == 0:
    print("No data found")
    exit(0)

for item in items:
    cc = item.properties.get('eo:cloud_cover', 'N/A')
    print(f"  {item.id}: cloud cover {cc}%")

print("\nLoading xarray datacube from COGs...")

data = stac_load(
    items,
    bands=["B04", "B08"],  # red and nir
    bbox=[-34.2, 39.65, -32.88, 41.55],
    crs="EPSG:32625",
    resolution=100,
    chunks={"x": 2048, "y": 2048}
)

# show structure
print(f"\nDatacube loaded:")
print(f"  Shape: {data.sizes['x']} x {data.sizes['y']} pixels")
print(f"  Time steps: {data.sizes.get('time', 1)}")
print(f"  Bands: {list(data.data_vars.keys())}")

# quick ndvi calc to show it works
if "B04" in data and "B08" in data:
    ndvi = (data["B08"] - data["B04"]) / (data["B08"] + data["B04"])
    print(f"\nNDVI calculated, shape: {ndvi.shape}")
    
    # stats
    ndvi_mean = float(ndvi.mean().compute())
    print(f"  Mean NDVI: {ndvi_mean:.3f}")
    
print("\nDone - datacube ready for anaylsis")