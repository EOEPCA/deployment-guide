# EOEPCA+ Security Scanner Deployment Guide (Trivy)

Running a security scanner is important for vulnerability management in an EOEPCA deployment, allowing you to detect when new vulnerabilities are published for both EOEPCA-published and third-party software artefacts present in your cluster. You can then take action such as updating image versions in your Helm configuration files. This is important even for freshly installed deployments as, whilst we will endeavour to update this guide to avoid vulnerable versions at each EOEPCA release, we do not do so in between releases.

Security scanners can also assess your Kubernetes configuration. This guide aims to achieve a baseline level of good security configuration, but a scanner will help ensure that your cluster and your custom modifications meet your particiular security goals and policies.

This guide and the EOEPCA project use Trivy, but alternatives such as NeuVector can be used instead.

---

## Introduction

This deployment uses Trivy Operator to run Trivy scans from within the Kubernetes cluster and save the results to custom resources. If you use ArgoCD then a UI plugin is available at https://github.com/mziyabo/argocd-trivy-extension that can display these results. Alternatively, you can view them with kubectl.

---

## Prerequisites

Before you begin, make sure you have the following:

| Component        | Requirement                            | Documentation Link                                                |
| ---------------- | -------------------------------------- | ----------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.32)              | [Installation Guide](kubernetes.md)             |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)         |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)     |

**Clone the Deployment Guide Repository:**

```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/trivy
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:

```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### Trivy Configuration

Trivy will check that container images come from trusted registries. The list of trusted registries should be configured to match those you expect. The list below is sufficient for EOEPCA.

```bash
kubectl create namespace trivy-system
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: extra-trivy-config
  namespace: trivy-system
data:
  trivy-config-data.yaml: |
    ksv0125:
      trusted_registries:
        - "docker.io"
        - "ghcr.io"
        - "quay.io"
        - "registry.k8s.io"
        - "gcr.io"
EOF
```

Run the configuration script:

```bash
bash configure-trivy-operator.sh
```

Install Trivy Operator using Helm:

```bash
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update aqua
helm upgrade -i trivy-operator aqua/trivy-operator \
     --namespace trivy-system \
     --create-namespace \
     --version 0.32.1 \
     --values generated-values.yaml
```

---

## Validation

**Automated Validation:**

```bash
bash validation.sh
```

This script checks that Trivy Operator is running and that reports have been generated. It may take some time before reports on all workloads have been generated.

---

**Manual Validation:**

1. **Check Trivy is Running**

Run

```bash
kubectl get all -n trivy-system
```

and you should see a Trivy Operator deployment running. You may also see some vulnerability report scan jobs and pods, which should be running or completed and not in an error state. By default these will be visible for ten minutes after they have run, but this can be changed in the values file.

2. **Check ConfigAuditReports**

Trivy should have generated or soon generate reports on the configuration of workloads in your cluster. You can summarize these with

```bash
kubectl get configauditreports --all-namespaces -o wide
```

The full list can be viewed by changing the output format to JSON or YAML (`-o yaml`).

3. **Check VulnerabilityReports**

Trivy should have generated or soon generate reports on vulnerable software detected within images used in your cluster. You can summarize these with

```bash
kubectl get vulnerabilityreports --all-namespaces -o wide
```

4. **Other Reports**

Trivy should generate several other reports which you can view with the following commands

```bash
kubectl get clustercompliancereports -o wide
kubectl get clusterconfigauditreports -o wide
kubectl get clusterinfraassessmentreports -o wide
kubectl get clusterrbacassessmentreports -o wide
kubectl get clustersbomreports -o wide 
kubectl get clustervulnerabilityreports -o wide
kubectl get exposedsecretreports -A -o wide
kubectl get infraassessmentreports -A -o wide
kubectl get rbacassessmentreports -A -o wide
kubectl get sbomreports -A -o wide
```
