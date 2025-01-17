
## Building Block Deployment Overview

This section provides instructions on how to deploy the various Building Blocks (BBs) that make up the EOEPCA+ ecosystem. Each Building Block is a modular component designed to perform specific functions within a platform.

## Scripted Deployment Approach

To simplify and standardise the deployment process, each Building Block comes with a set of scripts that automate configuration and installation tasks. 

1. **Prerequisites**: Each Building Block includes a list of prerequisites that must be met before deployment. These typically include Kubernetes, Helm, and other dependencies.
2.	**Configuration Script**: Each Building Block includes a `configure-<component>.sh` script that collects necessary configuration parameters from the user, such as domain names, storage classes, and TLS settings. It generates helm values and other configuration files based on your inputs. There is sometimes an `apply-secrets.sh` script too that applies additional resources to the cluster.
3.	**Validation**: Validation scripts are available to verify that the Building Block has been deployed correctly and is functioning as expected.
4.	**State Management**: Configuration details and generated secrets are saved to a state file (`~/.eoepca/state`) for reuse across different Building Blocks.

> When you run your first script, you will be prompted whether you want to use Cert-Manager for TLS certificate management. If you choose not to use Cert-Manager, you will need to create the TLS secrets manually before deploying each Building Block. 

## Building Blocks Overview

Below is a list of the EOEPCA+ Building Blocks available for deployment:

### 1. Identity & Access Management (IAM)

The Identity and Access Management (IAM) Building Block provides authentication and authorisation services within the EOEPCA+ ecosystem. It ensures users can access resources and services safely across the platform by managing identities, roles and permissions.

[Deploy IAM »](iam.md)

### 2. Resource Discovery

The Resource Discovery BB provides search and discovery of all types of resources available within the EOEPCA+ ecosystem - including datasets, processing workflows, ML models, applications, services, and more. It provides metadata management and search capabilities.

[Deploy Resource Discovery »](resource-discovery.md)

### 3. Resource Registration

Resource Registration BB allows for the addition of new resources to the EOEPCA+ ecosystem. This includes harvesting data from other (external) data sources - and associated population of Catalogue and Data Access services.

[Deploy Resource Registration »](resource-registration.md)

### 4. Data Access

The Data Access BB provides efficient access to Earth Observation data. It provides data visualisation and retrieval services, enabling users and applications to interact with large datasets.

[Deploy Data Access »](data-access.md)

### 5. Processing

The Processing BB provides deployment and execution of user-defined processing workflows within the EOEPCA+ platform - with support for OGC API Processes, OGC Application Packages and openEO.

[Deploy Processing »](processing.md)

### 6. Workspace

The Workspace BB provides collorative work environments for users and teams (projects). It offers workspace-scoped storage allowing projects to manage their own resources within the platform - with associated workspace services that support project work within the platform - such as catalogue, data access and processing.

[Deploy Workspace »](workspace.md)

### 7. MLOps (Machine Learning Operations)

The MLOps BB faciliates the machine learning model development lifecycle - including model training, model version management and management of training data - and supports discovery of published models and training datasets.

[Deploy MLOps »](mlops.md)

### 8. Resource Health

The Resource Health BB provides a flexible framework that allows platform users and operators to monitor the health and status of resources offered through the platform. This includes core platform services, as well as resources (datasets, workflows, etc.) offered through those platform services.

[Deploy Resource Health »](resource-health.md)

### 9. Application Hub

The Application Hub serves as a platform where users can discover, access, and launch Earth Observation (EO) applications. This includes a JupyterLab environment for interactive analysis with notebooks. It provides a user-friendly interface for managing application lifecycles and facilitates collaboration among users.

[Deploy Application Hub »](application-hub.md)

### 10. Application Quality

The Application Quality BB assesses and ensures the quality and compliance of EO applications before they are made available to users. It performs validation checks and enforces best practice for open reproducible science.

[Deploy Application Quality »](application-quality.md)
