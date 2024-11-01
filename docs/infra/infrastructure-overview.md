# EOEPCA+ Infrastructure Deployment Guide

This guide provides step-by-step instructions to set up the essential infrastructure required for deploying the EOEPCA+ ecosystem. We'll walk you through setting up a Kubernetes cluster using Rancher Kubernetes Engine (RKE), configuring networking, and establishing a load balancer and bastion host. These steps offer an example of how we set up our cluster, which you can follow or adapt to fit your environment.

Components that often vary between deployments—such as ingress controllers, TLS certificate management, and storage provisioning—are addressed in separate guides. This allows you to choose the approach that best suits your needs.

---

## Architecture Overview

- **Compute Instances**: Control plane node(s) and worker nodes for the Kubernetes cluster, a bastion host for secure access, and optional nodes for storage (e.g., NFS server).
- **Networking Components**: Virtual networks, subnets, and security groups/firewall rules to enable communication between instances and the internet.
- **Load Balancer**: Distributes traffic to the Kubernetes API server and the ingress controllers.
- **Kubernetes Cluster**: Deployed using RKE, includes control plane and worker nodes.
- **Bastion Host**: Provides secure access to instances within private networks.

---

## Prerequisites

- **Cloud Provider Access**: Access to a cloud provider (e.g., AWS, Azure, OpenStack) to create virtual machines and networking resources.
- **Domain Name**: A domain name you control (e.g., `example.com`) with the ability to manage DNS records.
- **Local Machine Setup**:
    - **Operating System**: Linux or Windows Subsystem for Linux (WSL).
    - **Tools**:
        - SSH client (`ssh`)
        - `git` ([Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git))
        - `kubectl` ([Installation Guide](https://kubernetes.io/docs/tasks/tools/))
        - `helm` ([Installation Guide](https://helm.sh/docs/intro/install/))
        - Helm plugins:<br>
            - `helm-git` ([Installation Guide](https://github.com/aslafy-z/helm-git?tab=readme-ov-file#install))
    - **Kubernetes Cluster Stack**:<br>
        _Optional - depending on existing cluster availablity_<br>
        NOTE that use of `rke` is assumed in the [Cluster Setup](./kubernetes-cluster-and-networking.md) guide.<br>
        - Rancher Kubernetes Engine (`rke`) ([Installation Guide](https://rancher.com/docs/rke/latest/en/installation/))
        - _Alternatives for local 'development' deployments:_
            - Minikube ([Installation Guide](https://minikube.sigs.k8s.io/docs/start))
            - k3d ([Installation Guide](https://k3d.io/#installation))
    - **Email Address**: For certificate issuance if using Let's Encrypt.

---

## Setup
Proceed to the following sections to set up the required infrastructure components:

1. [Cluster and Networking Setup](kubernetes-cluster-and-networking.md)

2. [Ingress Controller Setup](ingress-controller.md)

3. [TLS Certificate Management](tls/overview.md)
4. [Storage Provisioning](storage/storage-classes.md)

---

## Further Reading

- **Rancher Kubernetes Engine (RKE) Documentation**: [RKE Docs](https://rancher.com/docs/rke/latest/en/)
- **Kubernetes Documentation**: [Kubernetes Docs](https://kubernetes.io/docs/home/)
- **SSH Key Management**: [SSH Key Generation](https://www.ssh.com/academy/ssh/keygen)
- **Cloud Provider Documentation**:
  - **AWS**: [AWS Docs](https://docs.aws.amazon.com/)
  - **Azure**: [Azure Docs](https://docs.microsoft.com/en-us/azure/)
  - **OpenStack**: [OpenStack Docs](https://docs.openstack.org/)
