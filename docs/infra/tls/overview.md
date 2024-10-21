# TLS Certificate Management Guide

This guide provides options for managing TLS certificates in your Kubernetes cluster.

TLS certificates are essential for securing communication between clients and your services. This guide presents two options for managing TLS certificates, so you can choose the one that best fits your environment.


## Options for TLS Certificate Management
1. [**Using Cert-Manager with Let's Encrypt**](cert-manager.md)
2. [**Manual TLS Certificate Management**](manual-tls.md)

## Internal TLS
As the platform develops, there will be an increasing need for secure communication between services. For internal TLS setup, refer to the [Internal TLS Setup Guide](internal-tls.md).

## Further Reading

- **Cert-Manager Documentation**: [Cert-Manager Docs](https://cert-manager.io/docs/)
- **Kubernetes Ingress TLS**: [Ingress TLS Docs](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)
