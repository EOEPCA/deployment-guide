
# TLS Certificate Management Guide

TLS certificates are essential for securing communication between clients and your services. This guide outlines two options for managing TLS certificates in your Kubernetes cluster, allowing you to choose the one that best fits your environment.

## TLS Certificate Management Options

1. [Using Cert-Manager with Let's Encrypt](cert-manager.md)
2. [Manual TLS Certificate Management](manual-tls.md)

## Internal TLS

As the platform develops, secure communication between internal services becomes increasingly important. For setting up internal TLS, refer to the [Internal TLS Setup Guide](internal-tls.md).

## Further Reading

- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [Kubernetes Ingress TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)
