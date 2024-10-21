
## Application Deployment Overview

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

### 1. Application Hub

The Application Hub serves as a platform where users can discover, access, and launch Earth Observation (EO) applications. It provides a user-friendly interface for managing application lifecycles and facilitates collaboration among users.

[Deploy Application Hub »](application-hub.md)

### 2. Processing

The Processing is responsible for deploying and executing applications within the EOEPCA+ platform. It manages containerised workloads and orchestrates the execution of processing tasks.

[Deploy Processing »](processing.md)

### 3. Application Quality

The Application Quality Building Block assesses and ensures the quality and compliance of EO applications before they are made available to users. It performs validation checks and enforces standards.

[Deploy Application Quality »](application-quality.md)

### 4. Data Access

The Data Access Building Block provides secure and efficient access to Earth Observation data. It handles data retrieval, enabling users and applications to interact with large datasets.

[Deploy Data Access »](data-access.md)

### 5. MLOps (Machine Learning Operations)

MLOps facilitates the deployment and management of machine learning models within the EOEPCA+ platform. It streamlines the model lifecycle from development to production.

[Deploy MLOps »](mlops.md)

### 6. Resource Catalogue

The Resource Catalogue indexes and catalogs the resources available within the EOEPCA+ ecosystem, including datasets, applications, and services. It provides metadata management and search capabilities.

[Deploy Resource Catalogue »](resource-catalogue.md)

### 7. Resource Health

The Resource Health Building Block monitors the health and status of resources in the EOEPCA+ platform.

[Deploy Resource Health »](resource-health.md)

### 8. Resource Registration

Resource Registration allows for the addition of new resources to the EOEPCA+ ecosystem. It manages metadata and access controls.

[Deploy Resource Registration »](resource-registration.md)

### 9. Workspace

The Workspace Building Block provides a collaborative environment for users to interact with applications and data. It offers a shared workspace for users to collaborate on projects.

[Deploy Workspace »](workspace.md)