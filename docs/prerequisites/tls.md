
# TLS Management

TLS plays an essential role in securing both external and internal traffic for EOEPCA. In practice, EOEPCA’s Building Blocks often rely on certificates issued via a `ClusterIssuer`, enabling automatic certificate management for all namespaces in the cluster. We strongly recommend using cert-manager for this purpose.

**Options:**

1. **Cert-Manager (ClusterIssuer)**  

   - The simplest, most robust way to handle certificates in production.
   - You can create a `ClusterIssuer` that automatically issues and renews certs from Let’s Encrypt or your own CA.
   - In multi-tenant or multi-namespace scenarios, this is especially useful.

2. **Manual TLS (Development / Testing)**  

   - For local or internal demos, you may skip full automation.
   - You can manage a single wildcard certificate at the ingress level and manually rotate it when needed.

**Internal TLS:**

- Some internal components can also use TLS for pod-to-pod or service-to-service encryption (e.g., an internal OpenSearch cluster). 
- With cert-manager, you can easily issue internal certificates signed by a local CA (`ClusterIssuer`) so that pods trust each other automatically.

## Further Reading

- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [Kubernetes Ingress TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)
