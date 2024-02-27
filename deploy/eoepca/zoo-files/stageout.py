import os
import sys
import pystac
import botocore
import boto3
import shutil
from pystac.stac_io import DefaultStacIO, StacIO
from urllib.parse import urlparse
from datetime import datetime

cat_url = sys.argv[1]
bucket = sys.argv[2]
subfolder = sys.argv[3]
collection_id = sys.argv[4]
print(f"cat_url: {cat_url}", file=sys.stderr)
print(f"bucket: {bucket}", file=sys.stderr)
print(f"subfolder: {subfolder}", file=sys.stderr)
print(f"collection_id: {collection_id}", file=sys.stderr)

aws_access_key_id = os.environ["AWS_ACCESS_KEY_ID"]
aws_secret_access_key = os.environ["AWS_SECRET_ACCESS_KEY"]
region_name = os.environ["AWS_REGION"]
endpoint_url = os.environ["AWS_S3_ENDPOINT"]
print(f"aws_access_key_id: {aws_access_key_id}", file=sys.stderr)
print(f"aws_secret_access_key: {aws_secret_access_key}", file=sys.stderr)
print(f"region_name: {region_name}", file=sys.stderr)
print(f"endpoint_url: {endpoint_url}", file=sys.stderr)

shutil.copytree(cat_url, "/tmp/catalog")
cat = pystac.read_file(os.path.join("/tmp/catalog", "catalog.json"))

class CustomStacIO(DefaultStacIO):
    """Custom STAC IO class that uses boto3 to read from S3."""

    def __init__(self):
        self.session = botocore.session.Session()
        self.s3_client = self.session.create_client(
            service_name="s3",
            use_ssl=True,
            aws_access_key_id=aws_access_key_id,
            aws_secret_access_key=aws_secret_access_key,
            endpoint_url=endpoint_url,
            region_name=region_name,
        )

    def write_text(self, dest, txt, *args, **kwargs):
        parsed = urlparse(dest)
        if parsed.scheme == "s3":
            self.s3_client.put_object(
                Body=txt.encode("UTF-8"),
                Bucket=parsed.netloc,
                Key=parsed.path[1:],
                ContentType="application/geo+json",
            )
        else:
            super().write_text(dest, txt, *args, **kwargs)


client = boto3.client(
    "s3",
    aws_access_key_id=aws_access_key_id,
    aws_secret_access_key=aws_secret_access_key,
    endpoint_url=endpoint_url,
    region_name=region_name,
)

StacIO.set_default(CustomStacIO)

# create a STAC collection for the process
date = datetime.now().strftime("%Y-%m-%d")

dates = [datetime.strptime(
    f"{date}T00:00:00", "%Y-%m-%dT%H:%M:%S"
), datetime.strptime(f"{date}T23:59:59", "%Y-%m-%dT%H:%M:%S")]

collection = pystac.Collection(
  id=collection_id,
  description="description",
  extent=pystac.Extent(
    spatial=pystac.SpatialExtent([[-180, -90, 180, 90]]), 
    temporal=pystac.TemporalExtent(intervals=[[min(dates), max(dates)]])
  ),
  title="Processing results",
  href=f"s3://{bucket}/{subfolder}/collection.json",
  stac_extensions=[],
  keywords=["eoepca"],
  license="proprietary",
)

for index, link in enumerate(cat.links):
  if link.rel == "root":
      cat.links.pop(index) # remove root link

for item in cat.get_items():

    item.set_collection(collection)
    
    collection.add_item(item)
    
    for key, asset in item.get_assets().items():
        s3_path = os.path.normpath(
            os.path.join(subfolder, collection_id, item.id, os.path.basename(asset.href))
        )
        print(f"upload {asset.href} to s3://{bucket}/{s3_path}",file=sys.stderr)
        client.upload_file(
            asset.get_absolute_href(),
            bucket,
            s3_path,
        )
        asset.href = f"s3://{bucket}/{s3_path}"
        item.add_asset(key, asset)

collection.update_extent_from_items() 

cat.clear_items()

cat.add_child(collection)

cat.normalize_hrefs(f"s3://{bucket}/{subfolder}")

for item in collection.get_items():
    # upload item to S3
    print(f"upload {item.id} to s3://{bucket}/{subfolder}", file=sys.stderr)
    pystac.write_file(item, item.get_self_href())

# upload collection to S3
print(f"upload collection.json to s3://{bucket}/{subfolder}", file=sys.stderr)
pystac.write_file(collection, collection.get_self_href())

# upload catalog to S3
print(f"upload catalog.json to s3://{bucket}/{subfolder}", file=sys.stderr)
pystac.write_file(cat, cat.get_self_href())

print(f"s3://{bucket}/{subfolder}/catalog.json", file=sys.stdout)