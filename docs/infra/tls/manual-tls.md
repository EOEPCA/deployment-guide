
### Option 2: Manual TLS Certificate Management

**Use Case**:

- Environments where certificates are issued by an internal CA or where external certificate management is required.

Throughout each Building Block component deployment, you will be instructed what to call the varying TLS certificates. 

**Steps**:

1. **Obtain Certificates**:

   - Generate certificates using your internal CA or a third-party service.
   - Ensure the certificate's `Common Name` (CN) matches the domain name.

2. **Create a Kubernetes TLS Secret**:

   For each required TLS secret, run:
   ```bash
   kubectl create secret tls <secret-name> \
     --cert=path/to/tls.crt \
     --key=path/to/tls.key \
     -n <namespace>
   ```

3. **Verify the Secrets:**

   ```bash
   kubectl get secrets -n <namespace>
   ```

   Ensure that the secrets are listed and correctly created.
