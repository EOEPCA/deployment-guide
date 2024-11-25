# Application Hub Deployment Guide


> **Important Note**: While deployment will succeed, full operation is not available in this EOEPCA+ release due to the inability to configure OIDC settings in EOEPCA+'s current version. This guide will be updated once OIDC settings are available.

The **Application Hub** provides a suite of web-based tools, including JupyterLab for interactive analysis, Code Server for application development, and the capability to add user-defined interactive dashboards. It empowers users to manage and deliver work environments and tools for a wide range of tasks, such as developing, hosting, executing, and performing exploratory analysis of Earth Observation (EO) applications, all within a unified Cloud infrastructure.

***
## Introduction

The **Application Hub** serves diverse users with different needs and workflows. It provides a collaborative environment for developing, deploying, and running EO applications, fostering innovation and efficiency in the EO community.

***
## Architecture Overview

The Application Hub is architected to support various functionalities:

- **Interactive Analysis**: Provides JupyterLab environments for data scientists and researchers to perform exploratory data analysis.
- **Application Development**: Offers Code Server environments for developers to write, test, and debug code in languages like Python, R, or Java, with access to EO-specific libraries like SNAP and GDAL.
- **Custom Dashboards**: Allows users to create and deploy interactive dashboards tailored to specific analytical needs.
- **Unified Infrastructure**: Manages all tools and environments within a single Cloud infrastructure, ensuring consistency and scalability.


### Key Features

- **Management**: Aggregates and retrieves EO metadata across multiple sources.
- **Standards Compliance**: Integrates with existing systems using OGC CSW and STAC standards.
- **Discoverability**: Facilitates data discovery with OpenSearch and API Records support.
- **Scalability**: Built on PyCSW, allowing for flexible and scalable deployments.

***
## User Scenarios

The Application Hub accommodates various user roles and scenarios:

### Development Scenario

**Stakeholders**: Service Providers and Developers

Developers access the Application Hub to utilise a software development environment in a Software-as-a-Service (SaaS) model. They can create EO applications using programming languages like Python, R, or Java and leverage libraries such as SNAP and GDAL for processing and analysis. The platform supports:

- **Application Packaging**: Bundle EO applications with necessary configurations and dependencies.
- **Version Control**: Integrate with tools like Git for source code management.
- **Continuous Integration**: Use CI/CD pipelines for automated testing and deployment.
- **Collaboration**: Share code and resources within teams.

### Execution Scenario

**Stakeholders**: End-users (Scientists, Researchers, EO Community Members)

End-users can execute operational applications made available on the platform. They benefit from:

- **Data Access**: Utilise the platform's data holdings and data catalog to find compatible datasets.
- **Parameter Specification**: Input parameters required for application execution.
- **Monitoring**: Receive real-time updates on processing status, resource consumption estimates, and expected completion times.
- **Resource Management**: The platform handles resource allocation and scalability for application execution.

### Exploratory Analysis

**Stakeholders**: End-users and Developers

Users engage with the Application Hub’s SaaS products designed for in-depth interaction, analysis, and execution of EO applications:

- **Interactive Graphical Applications (IGAs)**: Containerised applications for geospatial data exploration.
- **Web Apps and Notebooks**: Specialised tools for data analysis and visualisation.
- **Customisable Dashboards**: Tailored interfaces to meet specific analytical needs.
- **In-Environment Execution**: Ability to execute new analyses or applications within the same environment.

***
## Prerequisites

| Component        | Requirement                            | Documentation Link                                                                            |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)                                         |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                     |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                 |
| Ingress          | Properly installed                     | [Installation Guide](../infra/ingress-controller.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../infra/tls/overview.md/)                             |
| OIDC             | OIDC                                   | TODO                                                                                          |

**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/app-hub
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

***
## Deployment


1. **Run the Setup Script**:

```bash
bash configure-app-hub.sh
```


2. **Key Configuration Parameters**:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
  - *Example*: `example.com`
- **`CLUSTER_ISSUER`** (if using `cert-manager`): Name of the ClusterIssuer.
  - *Example*: `letsencrypt-prod`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
  - *Example*: `default`
- **`APPHUB_CLIENT_SECRET`**: Client secret for OAuth2

**Important Notes:**

- **TLS Certificates**<br>
  If you choose **not** to use `cert-manager`, you will need to create the TLS secrets manually before deploying.
    - The required TLS secret names are:
      - `app-hub-tls`
    - For instructions on creating TLS secrets manually, please refer to the [Manual TLS Certificate Management](../infra/tls/manual-tls.md) section in the TLS Certificate Management Guide.
- **Node Selection**<br>
  The generated helm values include a `nodeSelector` that identifies the target nodes for spawned workloads...<br>
  ```
  nodeSelector:
    key: "node-role.kubernetes.io/worker"
    value: "true"
  ```
  As required, this node selector must be adjusted according to your Kubernetes cluster.

1. **Deploy the Application Hub Using Helm**

	Run the Helm install command using the generated values file:

```bash
helm repo add eoepca https://eoepca.github.io/helm-charts && \
helm repo update eoepca && \
helm upgrade -i application-hub eoepca/application-hub \
--version 2.1.0 \
--values generated-values.yaml \
--namespace application-hub \
--create-namespace
```

***
## Validation

**Automated Validation:**

```bash
bash validation.sh
```


**Manual Validation:**

1. **Check Kubernetes Resources:**

```bash
kubectl get all -l release=application-hub --all-namespaces
```

2. **Access Dashboard:**

```
https://app-hub.<your-domain>
```

---
## Operation

#### Configuring Groups and Users

1. **Access the Application Hub**:
    - Navigate to its URL.
    - Log in with administrative credentials.

2. **Manage Groups and Users**:
    - Go to the **Admin** menu.
    - Add groups (e.g., `group-1`, `group-2`, `group-3`).
    - Add users (`eric`, `bob`) to these groups as needed.

For detailed instructions, refer to the [Groups and Users Management Guide](https://eoepca.readthedocs.io/projects/deploy/en/stable/eoepca/application-hub/#groups-and-users).

### Configuring Application Profiles

Application profiles define how users interact with tools and applications, determining resource limits and available environments.

#### Defining Profiles

Define profiles in the `config.yml` under the Application Hub's Helm chart configurations:

```yaml
profiles:
  - id: profile_1
    groups:
      - group-A
      - group-B
    definition:
      display_name: Profile 1
      slug: profile_1_slug
      default: False
      kubespawner_override:
        cpu_limit: 4
        mem_limit: 8G
        image: eoepca/iat-jupyterlab:main

```
#### Using Profiles

Profiles link to specific user groups, controlling access and resource usage based on roles.

### Advanced Configuration

You can define environment variables, volumes, and Kubernetes RBAC settings to fine-tune the Application Hub's operation and security.

For a comprehensive guide, visit the [Application-Hub Context Configuration](https://eoepca.github.io/application-hub-context/configuration).

***
## Uninstallation

To uninstall the Application Hub and clean up associated resources:

`helm uninstall application-hub -n application-hub`

***
## Further Reading

- [Application Hub Design Document](https://eoepca.readthedocs.io/projects/application-hub/en/latest/)
- [EOEPCA+ Helm Charts Repository](https://github.com/EOEPCA/helm-charts)
- [EOEPCA+ Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide)
- [JupyterLab Documentation](https://jupyterlab.readthedocs.io/en/stable/)

***
## Feedback

If you encounter any issues or have suggestions for improvement, please open an issue on the [EOEPCA+Deployment Guide GitHub Repository](https://github.com/EOEPCA/deployment-guide/issues).