# Application Hub Deployment Guide

The **Application Hub** provides a suite of web-based tools—like JupyterLab and Code Server—for interactive analysis and application development on Earth Observation (EO) data. It can also host custom dashboards and interactive web apps

***

### Key Features

- **JupyterLab** for interactive analysis of EO data.
- **Code Server** for browser-based coding environments.
- **Custom Dashboards** for specialized visualizations or user-defined apps.
- **Multi-User, Multi-Profile** environment—users can be grouped, assigned different resource quotas, and use different container images.

### Architecture Overview

1. **JupyterHub** at the core, spawning user-specific pods.
2. **OIDC** for authentication & authorization.
3. **Profiles** to define CPU/RAM limits, images, volumes, environment variables, etc.
4. **Group-based Access** controlling which profiles are visible to which user groups.

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
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](../prerequisites/kubernetes.md)                                         |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                     |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                 |
| Ingress          | Properly installed                     | [Installation Guide](../prerequisites/ingress-controller.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)                             |
| OIDC             | OIDC                                   | See below                                                                                          |

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

1. **Configure OIDC Provider**:

To enable Jupyter notebooks and other interactive services to authenticate users, you must integrate the Application Hub with an OIDC identity provider:

Follow the steps in [Client Administration](../iam/client-management) to create a new Keycloak client for OAPIP. Use the following values when prompted:


- **`clientId`**: `application-hub`
- **`rootUrl`** and **`baseUrl`**: `https://app-hub.${INGRESS_HOST}`
- **`redirectUris`**: `https://app-hub.${INGRESS_HOST}/*` and `/*`
- **`secret`**:  A secure secret for the OIDC client. Or leave it blank to generate one.

> Ensure you have the **Client Secret** for the OIDC client. You’ll need it in the next step.

---

2. **Run the Setup Script**:

```bash
bash configure-app-hub.sh
```

**Key Configuration Parameters**:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - *Example*: `example.com`
- **`CLUSTER_ISSUER`** (if using `cert-manager`): Name of the ClusterIssuer.
    - *Example*: `letsencrypt-http01-apisix`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
    - *Example*: `standard`
- **`NODE_SELECTOR_KEY`**: Determine which nodes will run the Application Hub pods.
    - *Example*: `node-role.kubernetes.io/worker`
    - *Read more*: [Node Selector Documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector)
- **`NODE_SELECTOR_VALUE`**: Value for the node selector key.
    - *Example*: `worker`
- **`APPHUB_CLIENT_SECRET`**: The Keycloak OIDC client secret

---


3. **Deploy the Application Hub Using Helm**

```bash
helm repo add eoepca https://eoepca.github.io/helm-charts && \
helm repo update eoepca && \
helm upgrade -i application-hub eoepca/application-hub \
--version 2.1.0 \
--values generated-values.yaml \
--namespace application-hub \
--create-namespace
```

---

4. **Access the Application Hub**

By default, the `generated-values.yaml` file creates a **demo** admin user named `admin`. You can log into the Application Hub by signing into Keycloak with this `admin` user credentials.

> **Note**: This default setup is primarily for **testing or demonstrations**. In production, we strongly recommend managing users and groups via Keycloak (or another OIDC provider) and assigning roles accordingly. This ensures a more secure and maintainable approach to user management. For more details, see the [Jupyter Hub Documentation](https://z2jh.jupyter.org/en/stable/administrator/authentication.html) section below on configuring additional users, groups, and profiles.

***

## 5. Validation

### 5.1 Automated Validation

```bash
bash validation.sh
```

### 5.2 Manual Validation

1. **Check Kubernetes Resources**:
    
```bash
kubectl get pods -n application-hub
```

Ensure the JupyterHub pod(s) and other components are in the `Running` state.
    
2. **Access the Hub**:
    
- Go to `https://app-hub.<YOUR_DOMAIN>/`.
- You should be redirected to Keycloak (or your chosen OIDC provider) for login if OIDC is set up.
- Upon successful login, you’ll land in the JupyterHub interface (the "spawn" page).

3. **Spawn a Notebook**:
    
- If you have multiple **Profiles**, pick one.
- Wait for the container to start. You should end up in a JupyterLab interface.

If something fails (e.g., a 401 from Keycloak or a "profile list is empty" error), review the logs:

```bash
kubectl logs -n application-hub <application-hub-pod-name>
```

---

## 6. Usage

Below are some common tasks you might perform in the Application Hub. For advanced usage, see the [Jupyter Hub Docs](https://eoepca.readthedocs.io/projects/application-hub/en/latest/) and the included references.

### 6.1 Managing Groups & Users

1. **Log In as Admin**:
    
- Typically, you designate one or more Keycloak accounts as "admin" in the JupyterHub configuration.
- Once logged in, go to `https://app-hub.<YOUR_DOMAIN>/hub/admin`.

2. **Create Groups**:
    
- In the admin panel, create groups (e.g., `group-A`, `group-B`).
- Or use the JupyterHub REST API to create groups programmatically.

3. **Assign Users**:
    
- Add or remove users from groups in the admin UI or via the REST API.
- Group membership controls which **Profiles** the user sees (see next section).

### 6.2 Defining Profiles for Different Tooling

In `config.yml`, define one or more "profiles." Each profile corresponds to a specific container image and resource constraints. For instance:

```yaml
profiles:
  - id: profile_jupyter_python
    groups:
      - group-A
    definition:
      display_name: "Jupyter Python Env"
      slug: "python-env"
      kubespawner_override:
        cpu_limit: 2
        mem_limit: 4G
        image: "eoepca/iat-jupyterlab:latest"
```

- **`id`**: Internal identifier for the profile.
- **`groups`**: Which JupyterHub groups can see/spawn this profile.
- **`kubespawner_override`**: Resource limits, container image, etc.
- **`pod_env_vars`, `volumes`, `config_maps`**: Additional fields for environment variables, data volumes, or config maps.

Once you redeploy with the updated configuration, users in `group-A` can spawn notebooks using the "Jupyter Python Env" profile.

### 6.3 JupyterHub API

If you want to automate tasks—like adding groups, spinning up named servers, or managing pods—use the JupyterHub REST API.

- Acquire an **API token** (admin or appropriate privileges).
- Make HTTP requests to endpoints such as:
    - `GET /hub/api/groups`
    - `POST /hub/api/users/{username}/servers/{server_name}`

### 6.4 Running Code Server or Custom Dashboards

Besides JupyterLab, you can define profiles for other web-based apps (e.g., Code Server, RStudio, custom dashboards). Just specify their container images in the profile’s `kubespawner_override.image` field and any required environment variables or volumes.

---

## 7. Advanced Configuration

Check the [JupyterHub Configuration Reference](https://eoepca.github.io/application-hub-context/configuration/) for more advanced settings and options.

***
## Uninstallation

To uninstall the Application Hub and clean up associated resources:

```
helm uninstall application-hub -n application-hub
```

***
## Further Reading

- [Application Hub Design Document](https://eoepca.readthedocs.io/projects/application-hub/en/latest/)
- [EOEPCA+ Helm Charts Repository](https://github.com/EOEPCA/helm-charts)
- [EOEPCA+ Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide)
- [JupyterLab Documentation](https://jupyterlab.readthedocs.io/en/stable/)

***
## Feedback

If you encounter any issues or have suggestions for improvement, please open an issue on the [EOEPCA+Deployment Guide GitHub Repository](https://github.com/EOEPCA/deployment-guide/issues).