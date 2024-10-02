# openEO Geotrellis

openEO develops an API that allows users to connect to Earth observation cloud back-ends in a simple and unified way.
The project maintains the API and process specifications, and an open-source ecosystem with clients and server implementations.

## Prerequisites

### Spark Operator

As openEO runs on Apache Spark, we need a way to run this in a Kubernetes cluster. For this requirement, we leverage the [Kubeflow Spark-Operator](https://github.com/kubeflow/spark-operator). Basic instructions on how to get it running inside you cluster are:

```bash
helm install spark-operator spark-operator \
    --namespace spark-operator \
    --create-namespace \
    --repo https://kubeflow.github.io/spark-operator \
    --set webhook.enable=true \
    --set spark.jobNamespaces[0]=""
```

Take a look at the [values.yaml](https://github.com/kubeflow/spark-operator/blob/master/charts/spark-operator-chart/values.yaml) file for all the possible configuration options.

### ZooKeeper

openEO uses [Apache ZooKeeper](https://zookeeper.apache.org/) under the hood. To get a basic ZK installed in your cluster, follow these steps:

```bash
helm install zookeeper oci://registry-1.docker.io/bitnamicharts/zookeeper \
    --create-namespace \
    --namespace zookeeper
```

The possible configuration values can be found in the [values.yaml](https://github.com/bitnami/charts/blob/main/bitnami/zookeeper/values.yaml) file.

## Helm Chart

openEO can be deployed by Helm. A Chart can be found at the [openeo-geotrellis-kubernetes](https://github.com/Open-EO/openeo-geotrellis-kubernetes/tree/master/kubernetes/charts/sparkapplication) repo.

The releases of the Helm chart are also hosted on the [VITO Artifactory](https://artifactory.vgt.vito.be/helm-charts) instance.

Install openEO as follows in your cluster:

```bash
helm install openeo sparkapplication \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 0.14.9 \
    --namespace openeo \
    --create-namespace \
    --values values.yaml
```

Example values.yaml file:
```yaml
---
image: vito-docker.artifactory.vgt.vito.be/openeo-geotrellis-kube
imageVersion: latest
sparkVersion: 3.2.0
type: Java
driver:
  env:
    KUBE: "true"
    KUBE_OPENEO_API_PORT: "50001"
    PYTHONPATH: $PYTHONPATH:/opt/tensorflow/python38/2.3.0/:/opt/openeo/lib/python3.8/site-packages/
    ZOOKEEPERNODES: zookeeper.zookeeper.svc.cluster.local:2181
  podSecurityContext:
    fsGroup: 18585
    fsGroupChangePolicy: Always
executor:
  env:
    PYTHONPATH: $PYTHONPATH:/opt/tensorflow/python38/2.3.0/:/opt/openeo/lib/python3.8/site-packages/
fileDependencies:
  - local:///opt/layercatalog.json
  - local:///opt/log4j2.xml
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
          - configmaps
        verbs:
          - create
          - delete
          - deletecollection
          - list
  serviceAccountDriver: openeo
```

This gives you an `openeo-driver` pod that you can `port-forward` to on port 50001.

With the port-forward activated, you can access the openEO API with `curl -L localhost:50001`.
