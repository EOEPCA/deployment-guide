import openeo

connection = openeo.connect("https://openeo.test.eoepca.org")
connection.authenticate_oidc()
collections = connection.list_collections()
print(collections)

datacube = connection.load_collection(
    "sentinel-2",
    spatial_extent={"west": 5.0, "south": 51.0, "east": 6.0, "north": 52.0},
    temporal_extent=["2023-01-01", "2023-12-31"]
)

job = datacube.save_result(format="GTiff").create_job()
job.start_and_wait()