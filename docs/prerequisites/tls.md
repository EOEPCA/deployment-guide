
# TLS Management

TLS plays an essential role in securing both external and internal traffic for EOEPCA. In practice, EOEPCA’s Building Blocks often rely on certificates issued via a `ClusterIssuer`, enabling automatic certificate management for all namespaces in the cluster. We strongly recommend using cert-manager for this purpose.

**Options:**

1. **Cert-Manager with ClusterIssuer (Recommended for Production)**:  
     - Use a `ClusterIssuer` configured with Let’s Encrypt or another CA.  
     - This allows certificates to be requested and renewed automatically across all namespaces, simplifying management as your platform grows.
     - Ideal for production environments, as it combines automation with reliability.

2. **Manual TLS Management (For Development or Internal Testing)**:  
     - If automation and widespread distribution of certificates are less critical, you can use a single wildcard certificate at the ingress level or manually manage certificates on a per-service basis.
     - This approach may involve an `Issuer` limited to a single namespace or manual rotation of certificates when they expire.

**Internal TLS:**

Some internal EOEPCA services (e.g., OpenSearch components) also benefit from TLS. Using a `ClusterIssuer` makes it straightforward to secure internal communication without manually distributing certificates. Cert-manager can handle internal certificates just as easily as external ones, ensuring a consistent security model throughout your cluster.

## Further Reading

- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [Kubernetes Ingress TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)
