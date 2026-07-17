# Building Blocks

This section provides instructions on how to deploy the various Building Blocks (BBs) that make up the EOEPCA+ ecosystem. Each Building Block is a modular component designed to perform specific functions within the platform, and each is deployed the same scripted way - see [How Deployment Works](../index.md#how-deployment-works) if you haven't deployed a Building Block before.

## Building Blocks Overview

Below is a list of the EOEPCA+ Building Blocks available for deployment:

<div class="grid cards" markdown>

-   :material-shield-account:{ .lg .middle } **1. Identity & Access Management (IAM)**

    ---

    Authentication and authorisation services within the EOEPCA+ ecosystem. Manages identities, roles and permissions so users can safely access resources across the platform.

    [:octicons-arrow-right-24: Deploy IAM](iam/main-iam.md)

-   :material-magnify:{ .lg .middle } **2. Resource Discovery**

    ---

    Search and discovery of all types of resources - datasets, processing workflows, ML models, applications, services, and more - with metadata management and search capabilities.

    [:octicons-arrow-right-24: Deploy Resource Discovery](resource-discovery.md)

-   :material-database-plus:{ .lg .middle } **3. Resource Registration**

    ---

    Adds new resources to the EOEPCA+ ecosystem, including harvesting data from external sources and populating Catalogue and Data Access services.

    [:octicons-arrow-right-24: Deploy Resource Registration](resource-registration.md)

-   :material-database:{ .lg .middle } **4. Data Access**

    ---

    Efficient access to Earth Observation data, with visualisation and retrieval services enabling users and applications to interact with large datasets.

    [:octicons-arrow-right-24: Deploy Data Access](data-access.md)

-   :material-cube-scan:{ .lg .middle } **5. Datacube Access**

    ---

    Access to and exploration of multi-dimensional Earth Observation (EO) data using standard APIs.

    [:octicons-arrow-right-24: Deploy Datacube Access](datacube-access.md)

-   :material-transit-connection-variant:{ .lg .middle } **6. Data Gateway**

    ---

    A consolidated and consistent capability for accessing Earth Observation data from an extensible set of providers and datasets.

    [:octicons-arrow-right-24: Explore Data Gateway](data-gateway.md)

-   :material-progress-clock:{ .lg .middle } **7. Federated Data Proxy** _(Coming Soon)_

    ---

    A unified access layer for serving Earth Observation data from multiple internal and external providers, transparently to end-users. Under active development.

    [:octicons-arrow-right-24: Learn more](federated-data-proxy.md)

-   :material-cog-outline:{ .lg .middle } **8. Processing**

    ---

    Deployment and execution of user-defined processing workflows, with support for OGC API Processes, OGC Application Packages and openEO.

    [:octicons-arrow-right-24: Deploy Processing](processing.md)

-   :material-brain:{ .lg .middle } **9. MLOps** _(Machine Learning Operations)_

    ---

    Facilitates the ML model development lifecycle - model training, version management and training data management - and supports discovery of published models and datasets.

    [:octicons-arrow-right-24: Deploy MLOps](mlops.md)

-   :material-account-group:{ .lg .middle } **10. Workspace**

    ---

    Collaborative work environments for users and teams, offering workspace-scoped storage and services that support catalogue, data access and processing.

    [:octicons-arrow-right-24: Deploy Workspace](workspace.md)

-   :material-apps:{ .lg .middle } **11. Application Hub**

    ---

    Discover, access, and launch EO applications, including a JupyterLab environment for interactive analysis and collaboration among users.

    [:octicons-arrow-right-24: Deploy Application Hub](application-hub.md)

-   :material-heart-pulse:{ .lg .middle } **12. Resource Health**

    ---

    A flexible framework for platform users and operators to monitor the health and status of core services and platform resources.

    [:octicons-arrow-right-24: Deploy Resource Health](resource-health.md)

-   :material-check-decagram:{ .lg .middle } **13. Application Quality**

    ---

    Assesses and ensures the quality and compliance of EO applications, performing validation checks and enforcing best practice for open reproducible science.

    [:octicons-arrow-right-24: Deploy Application Quality](application-quality.md)

</div>
