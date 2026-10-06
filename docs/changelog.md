# Changelog

For release numbering and lifecycle policy, see [Release Strategy](release-strategy.md).

## Release 2.1

Git tag: `eoepca-2.1`

Release 2.1 is the first minor release of EOEPCA+ since Release 2.0. It adds the Operations building block, extends Notification & Automation with its own Helm chart, updates the components of the existing building blocks, and revises each building block page and its validation.

The release is accompanied by updated supporting materials for each building block:

* Notebooks - that provide a quick demonstration of core capabilities
* Tutorials - that showcase the building block and its basic installation in a generic reproducible environment

### Highlights

* **Operations** - new building block for metrics, logs, dashboards and alerting, with Prometheus, Grafana, Loki and Keep.
* **Notification & Automation** - new Helm chart turning GitHub and GitLab webhooks and Kubernetes events into CloudEvents, with an emailer and optional Kafka.
* **IAM** - Keycloak 26.7.2 is deployed by the Keycloak Operator, and public clients use PKCE.
* **Data Access** - collection-level access control when IAM is enabled, and an openEO API through titiler-openeo.
* **Resource Discovery** - optional protected transactional endpoint, and federated search across external OGC API - Records, STAC API and CSW catalogues.
* **Resource Registration** - Operaton replaces Flowable as the harvester workflow engine.
* **Workspace** - optional Keycloak SSO and OPA policy for Datalab sessions.
* **openEO Argo** - deployed from the published EODC chart and authenticated through IAM.
* **Datacube Access** - now provided as STAC best practice guidance with an example notebook, without a separate service.

The guide also adds [EOEPCA+ State](prerequisites/state.md) and [Release Strategy](release-strategy.md) pages, and new notebooks for Notification & Automation and Operations.

### Component Versions

The versions deployed by this guide, compared with Release 2.0. Helm chart versions are shown unless stated otherwise.

| Building Block | Component | EOEPCA+ 2.0 | EOEPCA+ 2.1 |
| --- | --- | --- | --- |
| Prerequisites | Kubernetes (k3s image used in the k3d example) | v1.32.9-k3s1 | v1.36.3-k3s1 |
| | APISIX | 2.10.0 | 2.16.0 |
| | cert-manager | v1.16.1 | v1.21.1 |
| | Kyverno | 3.6.2 | 3.7.2 |
| | Crossplane | 2.0.2 | 2.0.2 |
| | MinIO | 5.4.0 | 5.4.0 |
| | Harbor | 1.7.3 | 1.7.3 |
| | Envoy Gateway | 1.6.2 | 1.6.2 |
| IAM | `iam-bb` | 2.0.0 | 2.1.0-dev15 |
| | Keycloak | Bitnami chart 24.4.11 (image `eoepca/keycloak-with-opa-plugin:0.5.0`) | Keycloak Operator, Keycloak 26.7.2 |
| | OPA image | Not pinned | 1.7.1 |
| | OPAL image | 0.8.0 | 0.8.0 |
| Resource Discovery | `rm-resource-catalogue` | 2.0.0 | 2.1.0-dev1 |
| Data Access | eoAPI | 0.7.12 | 0.13.1 |
| | Crunchy Postgres Operator (PGO) | 5.6.0 | 6.0.1 |
| | STAC Manager | 0.0.11 | 1.0.3 |
| | titiler-openeo | - | `titiler-openeo-v0.12.0` (image v0.9.1) |
| | pgstac-geoparquet-exporter | - | v0.2.4 |
| | eoapi-support | 0.1.7 | 0.1.7 |
| | eoapi-maps-plugin | 0.0.21 | Removed |
| Resource Registration | `registration-api` | 2.0.0 | 2.1.0-dev2 |
| | `registration-harvester` (worker image) | 2.0.0 | 2.0.0 (2.1.0-rc1) |
| | Workflow engine | Flowable 7.0.0 | Operaton 1.0.6 |
| Datacube Access | `datacube-access` | 2.0.0-rc2 | Not deployed |
| Data Gateway | EODAG | Unpinned | 4.7.2 |
| | stac-fastapi-eodag | - | 0.4.0 |
| Processing - OGC API Processes | `zoo-project-dru` | 0.9.1 | 0.10.3 |
| Processing - openEO Geotrellis | spark-operator | 2.0.2 | 2.3.0 |
| | sparkapplication | 1.0.2 | 1.2.0 |
| Processing - openEO Argo | `openeo-argo` | Chart from Git | 2026.7.1 |
| Processing - openEO | `openeo-web-editor` | - | 0.2.0 |
| MLOps | GitLab | 9.1.4 | 9.1.4 |
| | SharingHub | 0.4.1 | 0.4.2 |
| | MLflow SharingHub | 0.2.0 | 0.2.0 |
| Workspace | `rm-workspace-api` | 2.0.0-rc.7 | 2.2.2 |
| | Workspace dependencies and pipeline | 2.0.0-rc.12 | 2.2.1 |
| Application Hub | `application-hub` | 2.1.0 | 2.1.0 |
| Application Quality | `application-quality-reference-deployment` | `main` branch | `reference-deployment` branch |
| | SonarQube | - | 2026.2.1 |
| Resource Health | `resource-health-reference-deployment` | 2.0.0 (chart from Git) | 2.1.3 |
| Notification & Automation | Knative Operator | v1.19.5 | v1.19.5 |
| | Knative Serving / Eventing | 1.17 / 1.18 | 1.17 / 1.18 |
| | `notification-automation` | - | 0.1.2 |
| | Strimzi Kafka Operator (Kafka) | - | 1.1.0 (Kafka 4.2.0) |
| Operations | kube-prometheus-stack | - | 83.1.0 |
| | Loki | - | 6.55.0 |
| | Keep | - | 0.1.95 |
| | oauth2-proxy | - | 10.4.2 |

### Upgrading from Release 2.0

Each building block page describes a fresh installation. Points that need particular attention when upgrading an existing 2.0 deployment:

* **IAM** - Keycloak moves from the Bitnami chart to the Keycloak Operator.
* **Data Access** - PGO moves from 5.x to 6.x, and `eoapi-maps-plugin` is no longer deployed.
* **Resource Registration** - the harvester workflow engine changes from Flowable to Operaton.
* **Datacube Access** - the `datacube-access` chart is no longer part of the deployment.
* **openEO Argo** - requires IAM; the basic-auth proxy is no longer provided.

For more details please refer to the documentation for each component, or ask the EOEPCA team for support - in particular if you are migrating an existing deployment to EOEPCA+ 2.1.

## Release 2.0

Git tag: `eoepca-2.0`

Release 2.0 is the first formal release of EOEPCA+, since the last EOEPCA release 1.4 - representing a full refresh of the EOEPCA+ building blocks. EOEPCA+ 2.0 provides many new capabilities, with improved stability - ready for production deployment.

The release is additionally accompanied by supporting materials - including, for each Building Block:

* Notebooks - that provide a quick demonstration of core capabilities
* Tutorials - that showcase the building block and its basic installation in a generic reproducible environment

The following table summarises the evolution that EOEPCA+ Release 2.0 represents compared to EOEPCA 1.4.

> Note that all EOEPCA+ 2.0 building blocks are integrated with the authentication and authorization approach of the IAM building block

| Building Block                    | EOEPCA 1.4                                                   | EOEPCA+ 2.0                                                  |                      Migration Strategy                      |
| --------------------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- | :----------------------------------------------------------: |
| Resource Discovery                | pycsw (all resource types)                                   | **pycsw (resource discovery)**<br />Catalogue for all resource types supporting Open Science<br />Key enhancements:<br />- Latest OGC API Records, incl. transactions<br />- Latest STAC API, incl. transactions, CEOS best practice<br />**eoAPI (data discovery)**<br />Data discovery, access and visualisation (see also Data Access)<br />Key capabilities:<br />- Latest STAC API, incl. transactions, CEOS best practice | **pycsw**<br />Upgrade<br /><br />**eoAPI**<br />New installation |
| Data Access                       | EOxServer                                                    | **eoAPI**<br />Data discovery, access and visualisation (see also Data Discovery)<br />Key capabilities:<br />- Latest STAC API<br />- TiTiler-PgSTAC raster tiling service (XYZ/OGC-WMTS, OGC API Tiles, COG dynamic tiling, Virtual mosaics)<br />- TiPg vector tiling service (OGC Features and Tiles)<br />- MultiDimensional dataset support via Xarray<br />- Scalable in production<br />**Additional**<br />- STAC Browser for data discovery and visualisation<br />- STAC Manager for metadata management |                       New installation                       |
| Resource Registration             | Registration API (bespoke)                                   | **Registration API**<br />API for registration of resources into discovery and access services.<br />- API via pygeoapi (OGC API Processes) for resource register and deregister<br />- Integrates with *Resource Discovery* and *Data Access*<br />- Resource types for reproducible science<br /><br />**Registration Harvester**<br />Automated harvesting of datasets (and other resources) from external providers into discovery and access services.<br />- Flowable BPMN Engine - extensible workflows for harvesting<br />Example workflows...<br />- Harvest Landsat data from USGS<br />- Harvest Sentinel data from CDSE<br />Generic workflows...<br />- Harvest from static STAC catalog<br />- Harvest from STAC API |                       New installation                       |
| Workspace                         | Workspace API (bespoke)<br /><br />Workspace Provisioning<br />*Helm templates for workspace definitions* | Isolated environments for users/teams providing storage/compute for data management, processing and collaboration.<br />Key capabilities:<br />- **Workspace API** preserved for workspace management<br />- Alternative declarative approach using Kubernetes custom resources<br />- **Workspace provisioning** via declarative Crossplane pipelines<br />- Object storage provisioning (declarative and via UI), with multiple buckets per workspace<br />- Workspace UI providing users an interactive web interface with: Terminal, Code Editor, Storage Browser<br />- Workspace UI provides user-controlled management of permissions and sharing, with RBAC approach<br />- Automated rollover of bucket credentials<br />- vCluster providing dedicated, isolated Kubernetes cluster for workspace user service provisioning<br />Workspace hibernate and auto-suspend |                       New installation                       |
| Datacube Access                   | n/a                                                          | Ensuring support for datacube semantics in EOEPCA+ BBs.<br />Key Capabilities:<br />- Filtered discovery and access to multi-dimensional datasets<br />- STAC Best Practice for Datacubes |                       New installation                       |
| Processing<br />OGC API Processes | ZOO-Project with Calrissian - Kubernetes Runner              | User-defined processing following OGC API Processes standard<br />**ZOO-Project (common)**<br />Key enhancements:<br />- Improved job log management<br />- OGC types in CWL for inputs/outputs (cwl2ogc)<br />- Zoo pod auto-scaling<br />- New Zoo web UI<br />- Many stability, efficiency and maintainability improvements<br />- Unit tests for OGC-AP Patterns (see below)<br /><br />**Kubernetes Runner (Calrissian)**<br />Key enhancements:<br />- GPU resource requirements in CWL and node selectors<br />- Jobs can use existing namespace<br />- Fully reworked Calrissian integration (new eoap-cwlwrap)<br /><br />**HPC Runner (Toil)**<br />- Zoo integration with Toil for HPC CWL execution<br /><br />**Additional**<br />- [Resources & Guides for Application Packages](https://github.com/eoap)<br />- Documented Application Package patterns, including datacubes<br />- OGC API Processes python client | **Zoo-Calrissian**<br />Upgrade<br /><br />**Zoo-Toil**<br />New Installation |
| Processing<br />openEO            | n/a                                                          | API providing a simple/unified approach for connection to Earth Observation platforms<br />**openeo-geotrellis**<br />Key capabilities:<br />- openEO API<br />- Predefined processing specifications for portable applications<br />- Dataset load via STAC - with many enhancements for compatibility and datacube support<br />- Support for running CWL/OGC-App-Package<br />- Many process improvements: geojson, spatial aggregation, bbox filter, ...<br />- Improvements for federation<br /><br />**openEO Client / Web Editor**<br />Key enhancements:<br />- Support for running CWL/OGC-App-Package |                       New Installation                       |
| Application Hub                   | JupyterHub-based                                             | Web-based tooling for interactive analysis and development<br />**JupyterHub-based**<br />Key enhancements:<br />- Support for init containers, and user image pull secrets<br />- Configuration generator tool - to tailor available applications<br />- Dask Gateway support<br />- Optional harbor for image proxy cache<br />- CSI annotations for persistent volume claims |                           Upgrade                            |
| IAM                               | Keycloak with gogatekeeper and Identity API                  | Authenticated user identity, and authorisation of access to platform resources<br />**Keycloak with APISIX, Open Policy Agent and Crossplane**<br />Key enhancements:<br />- Keycloak as for EOEPCA 1.4, with upgraded version<br />- Identity API deprecated in favour of Crossplane CRDs<br />- Crossplane Keycloak Provider for declarative configuration of Keycloak<br />- Open Policy Agent as policy engine<br />- APISIX (ingress) for policy enforcement - with plugins for Authn (OIDC) and Authz (UMA and OPA)<br />- Integration with other EOEPCA+ BBs for policy enforcement and resource sharing |                       New Installation                       |
| Data Gateway                      | n/a                                                          | **EODAG**<br />Capability for accessing the data offering of an extensible set of data providers and datasets<br />Key enhancements:<br />- STAC-formatted metadata representation<br />- Integrate FedEO CEOS STAC for CCI data<br />- Support STAC serialise/deserialise<br />- STAC metadata augmentation via xarray |                             n/a                              |
| Application Quality               | n/a                                                          | **Application Quality** supports the transition of scientific algorithms to production-grade workflows. This is achieved through automated pipelines that execute tooling which verifies workflow quality against industry best practices for coding and security.<br />- Python code quality checks<br />- Best practices for Jupyter Notebooks<br />- OGC Application Package validation<br />- Trivy vulnerability scanning<br />- Grafana dashboards and reports for quality outcomes |                       New Installation                       |

For more details please refer to the documentation for each component, or ask the EOEPCA team for support - in particular if you are migrating an existing deployment to EOEPCA+ 2.0.
