#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source ../cluster/functions
configureAction "$1"
initIpDefaults

domain="${2:-${default_domain}}"
NAMESPACE="zoo"

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="zoo-open"
else
  name="zoo"
fi

main() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall ades
  else
    values | helm ${ACTION_HELM} zoo-project-dru zoo-project-dru -f - \
      --repo https://zoo-project.github.io/charts/ \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 0.2.4
  fi
}

values() {
  cat - <<EOF
customConfig:
  main:
    eoepca: |-
      domain=${domain}
$(workspacePrefix)
cookiecutter:
  templateUrl: https://github.com/EOEPCA/eoepca-proc-service-template.git
  templateBranch: master
iam:
  enabled: false
ingress:
  enabled: ${OPEN_INGRESS}
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
  hosts:
  - host: ${name}.${domain}
    paths:
    - path: /
      pathType: ImplementationSpecific
  tls:
  - hosts:
    - ${name}.${domain}
    secretName: ${name}-tls
minio:
  enabled: false
persistence:
  procServicesStorageClass: ${ADES_STORAGE}
  storageClass: ${ADES_STORAGE}
  tmpStorageClass: ${ADES_STORAGE}
postgresql:
  primary:
    persistence:
      storageClass: ${ADES_STORAGE}
  readReplicas:
    persistence:
      storageClass: ${ADES_STORAGE}
rabbitmq:
  persistence:
    storageClass: ${ADES_STORAGE}
websocketd:
  enabled: false
workflow:
  defaultMaxRam: ${PROCESSING_MAX_RAM}
  defaultMaxCores: ${PROCESSING_MAX_CORES}
  inputs:
$(stageOutConfig)
  nodeSelector:
    minikube.k8s.io/primary: "true"
  storageClass: ${ADES_STORAGE}
zoofpm:
  autoscaling:
    enabled: false
  extraMountPoints: []
  image:
    tag: eoepca-983b8de2b98ce925cdc24753b17bc277261c0330
  replicaCount: 1
zookernel:
  extraMountPoints: []
  image:
    tag: eoepca-983b8de2b98ce925cdc24753b17bc277261c0330
files:
  # Directory 'files/cwlwrapper-assets' - assets for ConfigMap 'XXX-cwlwrapper-config'
  cwlwrapperAssets:
    # main.yaml: ""
    # rules.yaml: ""
    # stagein.yaml: ""
    # stageout.yaml: ""
$(stageOutYaml)
EOF
}

workspacePrefix() {
  if [ "${STAGEOUT_TARGET}" = "workspace" ]; then
  cat - <<EOF
      workspace_prefix=ws
EOF
  fi
}

# Destination service for stage-out
# If STAGEOUT_TARGET is "workspace" then these details will be looked-up from the user's workspace
stageOutConfig() {
  if [ "${STAGEOUT_TARGET}" = "minio" ]; then
    cat - <<EOF
    STAGEOUT_AWS_SERVICEURL: https://minio.${domain}
    STAGEOUT_AWS_ACCESS_KEY_ID: ${MINIO_ROOT_USER}
    STAGEOUT_AWS_SECRET_ACCESS_KEY: ${MINIO_ROOT_PASSWORD}
    STAGEOUT_AWS_REGION: RegionOne
    STAGEOUT_OUTPUT: eoepca
EOF
  fi
}

stageOutYaml() {
  cat - <<EOF
    stageout.yaml: |-
      cwlVersion: v1.0
      class: CommandLineTool
      id: stage-out
      doc: "Stage-out the results to S3"
      inputs:
        process:
          type: string
        collection_id:
          type: string
        STAGEOUT_OUTPUT:
          type: string
        STAGEOUT_AWS_ACCESS_KEY_ID:
          type: string
        STAGEOUT_AWS_SECRET_ACCESS_KEY:
          type: string
        STAGEOUT_AWS_REGION:
          type: string
        STAGEOUT_AWS_SERVICEURL:
          type: string
      outputs:
        StacCatalogUri:
          outputBinding:
            outputEval: \${  return "s3://" + inputs.STAGEOUT_OUTPUT + "/" + inputs.process + "/catalog.json"; }
          type: string
      baseCommand:
        - python
        - stage.py
      arguments:
        - \$( inputs.wf_outputs.path )
        - \$( inputs.STAGEOUT_OUTPUT )
        - \$( inputs.process )
        - \$( inputs.collection_id )
      requirements:
        DockerRequirement:
          dockerPull: ghcr.io/terradue/ogc-eo-application-package-hands-on/stage:1.3.2
        InlineJavascriptRequirement: {}
        EnvVarRequirement:
          envDef:
            AWS_ACCESS_KEY_ID: \$( inputs.STAGEOUT_AWS_ACCESS_KEY_ID )
            AWS_SECRET_ACCESS_KEY: \$( inputs.STAGEOUT_AWS_SECRET_ACCESS_KEY )
            AWS_REGION: \$( inputs.STAGEOUT_AWS_REGION )
            AWS_S3_ENDPOINT: \$( inputs.STAGEOUT_AWS_SERVICEURL )
        InitialWorkDirRequirement:
          listing:
            - entryname: stage.py
              entry: |-
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
EOF
}

main "$@"
