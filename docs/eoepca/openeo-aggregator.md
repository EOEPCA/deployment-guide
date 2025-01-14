# openEO Aggregator

The openEO Aggregator is a software component to group multiple openEO back-ends together into a unified, federated openEO processing platform.

For more details on the design and configuration, please read the [dedicated documentation](https://open-eo.github.io/openeo-aggregator/).

## Helm chart

A Chart can be found at the [openeo-geotrellis-kubernetes](https://github.com/Open-EO/openeo-geotrellis-kubernetes/tree/master/kubernetes/charts/openeo-aggregator) repo.

The releases of the Helm chart are also hosted on the [VITO Artifactory](https://artifactory.vgt.vito.be/helm-charts) instance.

Install openEO Aggregator as follows in your cluster:

```bash
helm install openeo-aggregator openeo-aggregator \
    --repo https://artifactory.vgt.vito.be/artifactory/helm-charts \
    --version 0.1.2 \
    --namespace openeo-aggregator \
    --create-namespace \
    --values values.yaml
```

An example `values.yaml` file:

```yaml
---
envVars:
  ENV: "prod"
  ZOOKEEPERNODES: zookeeper.zookeeper-prod.svc.cluster.local:2181
  GUNICORN_CMD_ARGS: "--bind=0.0.0.0:8080 --workers=10 --threads=1 --timeout=900"
image:
  repository: vito-docker.artifactory.vgt.vito.be/openeo-aggregator
  tag: 0.39
```
