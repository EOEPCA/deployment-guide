# Application Quality Deployment Guide

The **Application Quality** Building Block supports the evolution of scientific algorithms from research projects to production environments. It provides tools for verifying non-functional requirements, including code quality, adherence to best practices, and performance optimisation through testing.

---

## Introduction

The Application Quality BB delivers a set of services that can be used in automated pipelines linked to the source and runtime resources of processing workflow developments. It includes:

- **Development Best Practice**: Analysis of source code and repositories for code quality and adherence to best practices.
- **Application Quality Tooling**: Tools that complement development best practices, such as vulnerability scanning.
- **Application Performance**: Tools supporting performance testing and optimisation of processing workflows.

### Key Features

- **Code Analysis**: Static code analysis to identify errors, complexity, maintainability issues, and known vulnerabilities.
- **Best Practices Enforcement**: Checks for adherence to best practices for reproducible open science.
- **Performance Testing**: Test environments for executing workflows and collecting performance metrics.
- **Automation Support**: Supports automated pipelines triggered via the Notification & Automation BB.
- **Web Portal**: Provides a web-enabled UI for interactive access to all capabilities.

---

## Prerequisites

Before deploying the Application Quality Building Block, ensure you have the following:

| Component        | Requirement                            | Documentation Link                                                                                  |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.28)              | [Installation Guide](../infra/kubernetes-cluster-and-networking.md)                                               |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                           |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                       |
| Ingress          | Properly installed                     | [Ingress Controllers](../infra/ingress-controller.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../infra/tls/overview.md/)                                   |


**Clone the Deployment Guide Repository:**

```bash
git clone -b 2.0-beta https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/application-quality
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

The configuration script will prompt you for necessary configuration values, generate any required secrets, and create configuration files for the Application Quality deployment.

```bash
bash configure-application-quality.sh
```

**Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
  - *Example*: `example.com`
- **`CLUSTER_ISSUER`**: Cert-manager Cluster Issuer for TLS certificates.
  - *Example*: `letsencrypt-prod`
- **`STORAGE_CLASS`**: Storage class for persistent volumes.
 - *Example*: `managed-nfs-storage-retain`

### 2. Deploy Application Quality Using Helm

Deploy the Application Quality Building Block using the Helm chart and the generated configuration file.

```bash
git clone https://github.com/EOEPCA/application-quality reference-repo

helm install application-quality reference-repo/helm/ \
  --namespace application-quality \
  --create-namespace \
  --values generated-values.yaml
```


---

## Validation

**Automated Validation:**

```bash
bash validation.sh
```

**Further Validation:**

1. **Check Kubernetes Resources:**

   ```bash
   kubectl get all -n application-quality
   ```

2. **Access Application Quality Web Interface:**

   Open a web browser and navigate to: `https://application-quality.<your-ingress-host>/`

3. **Test Application Functionality:**

   Verify that the Application Quality services are operational by performing test actions through the web interface.

---

## Uninstallation

To uninstall the Application Quality Building Block and clean up associated resources:

```bash
helm uninstall application-quality -n application-quality

kubectl delete namespace application-quality
```

**Additional Cleanup:**

- Delete any Persistent Volume Claims (PVCs) if used:

  ```bash
  kubectl delete pvc --all -n application-quality
  ```

- Delete the namespace if desired:

  ```bash
  kubectl delete namespace application-quality
  ```

---

## Further Reading

- [Application Quality GitHub Repository](https://github.com/EOEPCA/application-quality)
- [Application Quality Documentation](https://eoepca.readthedocs.io/projects/application-quality/en/latest/)
