# Processing - openEO Engine (Early Access)

**Integration of the openEO Engine has not been completed in this release.**

Instead we provide the following **work-in-progress** that provides some raw steps that can be used for early access:

* **openEO Geotrellis**<br>
  _Provides an API that allows users to connect to Earth observation cloud back-ends in a simple and unified way_
* **openEO Aggregator**<br>
  _Provides a software component to group multiple openEO back-ends together into a unified, federated openEO processing platform_

---

## openEO Geotrellis

openEO develops an API that allows users to connect to Earth observation cloud back-ends in a simple and unified way.
The project maintains the API and process specifications, and an open-source ecosystem with clients and server implementations.

### Prerequisites

#### Spark Operator

As openEO runs on Apache Spark, we need a way to run this in a Kubernetes cluster. For this requirement, we leverage the [Kubeflow Spark-Operator](https://github.com/kubeflow/spark-operator). Basic instructions on how to get it running inside you cluster are:

```bash
helm upgrade -i openeo-geotrellis-sparkoperator spark-operator \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 2.0.2 \
    --namespace openeo-geotrellis \
    --create-namespace \
    --set image.registry=vito-docker.artifactory.vgt.vito.be \
    --set image.repository=spark-operator \
    --set "image.tag=v1beta2-2.0.2-3.5.2" \
    --set controller.batchScheduler.enable=true \
    --set controller.podMonitor.create=false \
    --set controller.uiIngress.enable=false \
    --set controller.resources.requests.cpu=200m \
    --set webhook.resources.requests.cpu=300m \
    --set spark.jobNamespaces\[0\]=''
```

Take a look at the [values.yaml](https://github.com/kubeflow/spark-operator/blob/master/charts/spark-operator-chart/values.yaml) file for all the possible configuration options.

#### ZooKeeper

openEO uses [Apache ZooKeeper](https://zookeeper.apache.org/) under the hood. To get a basic ZK installed in your cluster, follow these steps:<br>
_Note use of variables `${...}` that should be substituted with appropriate values_

```bash
helm upgrade -i openeo-geotrellis-zookeeper zookeeper \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 11.1.6 \
    --namespace openeo-geotrellis \
    --create-namespace \
    --set global.storageClass=${STORAGE_CLASS} \
    --set replicacount=1 \
    --set autopurge.purgeInterval=1 \
    --set persistence.storageClass=${STORAGE_CLASS} \
    --set persistence.size=5Gi \
    --set resources.requests.memory=1024Mi
```

The possible configuration values can be found in the [values.yaml](https://github.com/bitnami/charts/blob/main/bitnami/zookeeper/values.yaml) file.

### Helm Chart

openEO can be deployed by Helm. A Chart can be found at the [openeo-geotrellis-kubernetes](https://github.com/Open-EO/openeo-geotrellis-kubernetes/tree/master/kubernetes/charts/sparkapplication) repo.

The releases of the Helm chart are also hosted on the [VITO Artifactory](https://artifactory.vgt.vito.be/helm-charts) instance.

Install openEO as follows in your cluster:

```bash
helm upgrade -i openeo-geotrellis-openeo sparkapplication \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 0.16.3 \
    --namespace openeo-geotrellis \
    --create-namespace \
    --values values.yaml
```

Example `values.yaml` file:<br>
_Note use of variables `${...}` that should be substituted with appropriate values_
```yaml
---
image: eoepca/openeo-geotrellis-kube
imageVersion: 2.0-beta2
imagePullPolicy: Always
sparkVersion: 3.2.0
configMaps:
  backendConfig: |
    from pathlib import Path


    from openeo_driver.users.oidc import OidcProvider
    from openeogeotrellis.config import GpsBackendConfig
    from openeogeotrellis.deploy import (
        build_gps_backend_deploy_metadata,
        find_geotrellis_jars,
    )


    capabilities_deploy_metadata = build_gps_backend_deploy_metadata(
        packages=[
            "openeo",
            "openeo_driver",
            "openeo-geopyspark",
            "openeo_udf",
            "geopyspark",
        ],
        jar_paths=find_geotrellis_jars(extra_search_locations=[Path("/opt")]),
    )

    oidc_providers = [
        OidcProvider(
            id="egi",
            title="EGI Check-in",
            issuer="https://aai.egi.eu/auth/realms/egi/",
            scopes=["openid", "email"],
            default_clients=[
                {
                    "id": "vito-default-client",
                    "grant_types": [
                        "authorization_code+pkce",
                        "urn:ietf:params:oauth:grant-type:device_code+pkce",
                        "refresh_token",
                    ],
                    "redirect_urls": ["https://editor.openeo.org"],
                }
            ],
        ),
        OidcProvider(
            id="egi-dev",
            title="EGI Check-in (dev)",
            issuer="https://aai-dev.egi.eu/auth/realms/egi/",
            default_clients=[
                {
                    "id": "openeo-eoepca-demo",
                    "grant_types": [
                        "authorization_code+pkce",
                        "urn:ietf:params:oauth:grant-type:device_code+pkce",
                        "refresh_token",
                    ],
                    "redirect_urls": ["https://editor.openeo.org"],
                }
            ],
        ),
    ]

    config = GpsBackendConfig(
        id="eoepca-openeo-demo",
        capabilities_title="Demo openEO/EOEPCA+ service (GeoPySpark)",
        capabilities_description="openEO backend based on GeoPyspark stack for EOEPCA+ demo",
        capabilities_deploy_metadata=capabilities_deploy_metadata,
        oidc_providers=oidc_providers,
        enable_basic_auth=True,
        valid_basic_auth=lambda u, p: p == f"{u}123",
    )
  layerCatalog: |
    [
      {
        "id": "TestCollection-LonLat16x16",
        "description": "[DEBUGGING] Fast and predictable layer for debugging purposes. One sample every 5 days. Resolution will vary, to always output 16x16 pixels.",
        "experimental": true,
        "_vito": {"data_source": {"type": "testing"}},
        "cube:dimensions": {
          "x": {"type": "spatial", "axis": "x", "reference_system": 4326},
          "y": {"type": "spatial", "axis": "y", "reference_system": 4326},
          "t": {"type": "temporal"},
          "bands": {
            "type": "bands",
            "values": [
              "Flat:0",
              "Flat:1",
              "Flat:2",
              "TileCol",
              "TileRow",
              "TileColRow:10",
              "Longitude",
              "Latitude",
              "Year",
              "Month",
              "Day"
            ]
          }
        },
        "extent": {
          "spatial": {"bbox": [[-180, -56, 180, 83]]},
          "temporal": {"interval": [["2000-01-01", null]]}
        }
      }
    ]
driver:
  env:
    KUBE: "true"
    KUBE_OPENEO_API_PORT: "50001"
    PYTHONPATH: $PYTHONPATH:/opt/tensorflow/python38/2.3.0/:/opt/openeo/lib/python3.8/site-packages/
    ZOOKEEPERNODES: openeo-geotrellis-zookeeper.openeo-geotrellis.svc.cluster.local:2181
  podSecurityContext:
    fsGroup: 18585
    fsGroupChangePolicy: Always
executor:
  env:
    PYTHONPATH: $PYTHONPATH:/opt/tensorflow/python38/2.3.0/:/opt/openeo/lib/python3.8/site-packages/
existingConfigMaps: false
fileDependencies:
  - local:///opt/layercatalog/layercatalog.json
  - local:///opt/log4j2.xml
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: apisix
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
    k8s.apisix.apache.org/enable-cors: "true"
    k8s.apisix.apache.org/http-to-https: "true"
  hosts:
    - host: openeo.${INGRESS_HOST}
      paths:
        - /
  tls:
    - hosts:
        - openeo.${INGRESS_HOST}
      secretName: openeo-geotrellis-openeo-sparkapplication-cert
jarDependencies:
  - local:///opt/geotrellis-extensions-static.jar
mainApplicationFile: local:///opt/openeo/lib64/python3.8/site-packages/openeogeotrellis/deploy/kube.py
sparkConf:
  spark.executorEnv.DRIVER_IMPLEMENTATION_PACKAGE: openeogeotrellis
  spark.appMasterEnv.DRIVER_IMPLEMENTATION_PACKAGE: openeogeotrellis
service:
  enabled: true
  port: 50001
ha:
  enabled: false
rbac:
  create: true
  role:
    rules:
      - apiGroups:
          - ""
        resources:
          - pods
        verbs:
          - create
          - delete
          - deletecollection
          - get
          - list
          - patch
          - watch
      - apiGroups:
          - ""
        resources:
          - services
        verbs:
          - deletecollection
          - list
      - apiGroups:
          - ""
        resources:
          - configmaps
        verbs:
          - create
          - delete
          - deletecollection
          - list
      - apiGroups:
          - sparkoperator.k8s.io
        resources:
          - sparkapplications
        verbs:
          - create
          - delete
          - get
          - list
      - apiGroups:
          - ""
        resources:
          - persistentvolumeclaims
        verbs:
          - create
          - delete
          - deletecollection
          - list
  serviceAccountDriver: openeo
```

This gives you an `openeo-driver` pod that you can `port-forward` to on port 50001.

With the port-forward activated, you can access the openEO API with `curl -L localhost:50001`.

---

## openEO Aggregator

The openEO Aggregator is a software component to group multiple openEO back-ends together into a unified, federated openEO processing platform.

For more details on the design and configuration, please read the [dedicated documentation](https://open-eo.github.io/openeo-aggregator/).

### Helm chart

A Chart can be found at the [openeo-geotrellis-kubernetes](https://github.com/Open-EO/openeo-geotrellis-kubernetes/tree/master/kubernetes/charts/openeo-aggregator) repo.

The releases of the Helm chart are also hosted on the [VITO Artifactory](https://artifactory.vgt.vito.be/helm-charts) instance.

Install openEO Aggregator as follows in your cluster:

```bash
helm upgrade -i openeofed openeo-aggregator \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 2025.01.10-14 \
    --namespace openeofed \
    --create-namespace \
    --values values.yaml
```

An example `values.yaml` file:

```yaml
---
configMaps:
  conf: |
    from openeo_aggregator.config import AggregatorBackendConfig
    from openeo_driver.users.oidc import OidcProvider

    oidc_providers = [
        OidcProvider(
            id="egi",
            title="EGI Check-in",
            issuer="https://aai.egi.eu/auth/realms/egi/",
            scopes=["openid", "email"],
            default_clients=[
                {
                    "id": "vito-default-client",
                    "grant_types": [
                        "authorization_code+pkce",
                        "urn:ietf:params:oauth:grant-type:device_code+pkce",
                        "refresh_token",
                    ],
                    "redirect_urls": ["https://editor.openeo.org"],
                }
            ],
        ),
        OidcProvider(
            id="egi-dev",
            title="EGI Check-in (dev)",
            issuer="https://aai-dev.egi.eu/auth/realms/egi/",
            scopes=["openid", "email"],
            default_clients=[
                {
                    "id": "openeo-eoepca-demo",
                    "grant_types": [
                        "authorization_code+pkce",
                        "urn:ietf:params:oauth:grant-type:device_code+pkce",
                        "refresh_token",
                    ],
                    "redirect_urls": ["https://editor.openeo.org"],
                }
            ],
        ),
    ]

    config = AggregatorBackendConfig(
        id="openeo-eoepca-aggregator-demo",
        capabilities_title="openEO/EOEPCA+ Federation Demo",
        capabilities_description="openEO demo federation service for EOEPCA+",
        oidc_providers=oidc_providers,
        aggregator_backends={
            "terrascope": "https://openeo-dev.vito.be/openeo/1.2/",
            "eoepca": "https://openeo.${INGRESS_HOST}/openeo/1.2/",
        },
    )

envVars:
  ENV: "prod"
  ZOOKEEPERNODES: openeo-geotrellis-zookeeper.openeo-geotrellis.svc.cluster.local:2181
  GUNICORN_CMD_ARGS: "--bind=0.0.0.0:8080 --workers=10 --threads=1 --timeout=900"
existingConfigMaps: false
fullnameOverride: openeofed
image:
  pullPolicy: Always
  repository: vito-docker.artifactory.vgt.vito.be/openeo-aggregator
  tag: latest
replicaCount: 1
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: apisix
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
    k8s.apisix.apache.org/enable-cors: "true"
    k8s.apisix.apache.org/http-to-https: "true"
  hosts:
    - host: openeofed.${INGRESS_HOST}
      paths:
        - path: /.well-known/openeo
          pathType: Prefix
        - path: /openeo
          pathType: Prefix
  tls:
    - secretName: openeofed-cert
      hosts:
        - openeofed.${INGRESS_HOST}
```
