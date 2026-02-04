# Application Hub Deployment Guide

> **OIDC** is currently a requirement for the Application Hub. This is a work in progress and will be updated in the future.

The **Application Hub** provides a suite of web-based tools—like JupyterLab and Code Server—for interactive analysis and application development on Earth Observation (EO) data. It can also host custom dashboards and interactive web apps

---

## Introduction

The Application Hub Building Block provides JupyterLab notebooks, Code Server and custom web applications for EO data analysis and processing.

The building block offers:

- JupyterLab for interactive data analysis and notebook execution
- Code Server for browser-based development environments
- Multi-user support with profile-based resource allocation
- Group-based access control for different user categories
- Integration with OIDC for authentication
- Persistent storage for user workspaces
- Customisable container images per profile

---

## Prerequisites

Before deploying the Application Hub, ensure you have the following:

| Component          | Requirement                            | Documentation Link                                               |
| ------------------ | -------------------------------------- | ---------------------------------------------------------------- |
| Kubernetes         | Cluster (tested on v1.32)              | [Installation Guide](../prerequisites/kubernetes.md)             |
| Helm               | Version 3.8 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)        |
| kubectl            | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)    |
| Ingress Controller | Properly installed (NGINX or APISIX)   | [Installation Guide](../prerequisites/ingress/overview.md)       |
| TLS Certificates   | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)      |
| OIDC Provider      | Keycloak or compatible                 | [IAM Deployment Guide](../building-blocks/iam/main-iam.md)       |
| Storage Class      | For persistent volumes                 | Default or custom storage class                                  |
| Crossplane         | Properly installed                     | [Installation Guide](../prerequisites/crossplane.md)             |

**Clone the Deployment Guide Repository:**
```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/app-hub
```

**Validate your environment:**

Run the validation script to ensure all prerequisites are met:
```bash
bash check-prerequisites.sh
```

---

## Deployment Steps

### 1. Run the Configuration Script

```bash
bash configure-app-hub.sh
```

**Core Configuration Parameters**

During the script execution, you will be prompted to provide:

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - *Example*: `example.com`
- **`PERSISTENT_STORAGECLASS`**: Storage class for persistent volumes.
    - *Example*: `standard`
- **`CLUSTER_ISSUER`** (if using `cert-manager`): Name of the ClusterIssuer.
    - *Example*: `letsencrypt-http01-apisix`
- **`NODE_SELECTOR_KEY`**: Determine which nodes will run the Application Hub pods.
    - *Example*: `kubernetes.io/os`
    - *Read more*: [Node Selector Documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector)
- **`NODE_SELECTOR_VALUE`**: Value for the node selector key.
    - *Example*: `linux`

**OIDC Configuration (We will set this up in the next step)**:

- **`KEYCLOAK_HOST`**: OIDC provider base domain will be asked if this hasn't been set. JupyterHub requires an OIDC provider for authentication.
    - *Example*: `auth.example.com` 
- **`APPHUB_CLIENT_ID`**: Client ID for the OIDC provider.
    - *Example*: `application-hub`

---

### 2. **Create a Keycloak Client**:

To enable Jupyter notebooks and other interactive services to authenticate users, you must integrate the Application Hub with an OIDC identity provider. This requires creation of a `Client` in Keycloak (part of IAM BB).

The client can be created using the Crossplane Keycloak provider via the `Client` CRD.

```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${APPHUB_CLIENT_ID}-keycloak-client
  namespace: iam-management
stringData:
  client_secret: ${APPHUB_CLIENT_SECRET}
---
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: ${APPHUB_CLIENT_ID}
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: ${APPHUB_CLIENT_ID}
    name: Application Hub
    description: Application Hub OIDC
    enabled: true
    accessType: CONFIDENTIAL
    rootUrl: ${HTTP_SCHEME}://app-hub.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://app-hub.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://app-hub.${INGRESS_HOST}
    serviceAccountsEnabled: true
    directAccessGrantsEnabled: true
    standardFlowEnabled: true
    oauth2DeviceAuthorizationGrantEnabled: true
    useRefreshTokens: true
    authorization:
      - allowRemoteResourceManagement: false
        decisionStrategy: UNANIMOUS
        keepDefaults: true
        policyEnforcementMode: ENFORCING
    validRedirectUris:
      - "/*"
    webOrigins:
      - "/*"
    clientSecretSecretRef:
      name: ${APPHUB_CLIENT_ID}-keycloak-client
      key: client_secret
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

The `Client` should be created successfully.

### 3. **Deploy the Application Hub Using Helm**

```bash
helm repo add eoepca https://eoepca.github.io/helm-charts
helm repo update eoepca
helm upgrade -i application-hub eoepca/application-hub \
--version 2.1.0 \
--values generated-values.yaml \
--namespace application-hub \
--create-namespace
```

#### 3.1. Configure Ingress

```bash
kubectl apply -f generated-ingress.yaml
```

### 4. **Create an admin user**

By default, the Application Hub has a **demo** admin user named `eric`. You will need to create this user in Keycloak (or your OIDC provider) to access the Application Hub admin.

The user can be created declaratively using the CRD defined by the Crossplane Keycloak provider. A `Secret` is used to inject the password securely.

```bash
source ~/.eoepca/state
username="eric"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${username}-user-password
  namespace: iam-management
stringData:
  password: ${KEYCLOAK_TEST_PASSWORD}
---
apiVersion: user.keycloak.m.crossplane.io/v1alpha1
kind: User
metadata:
  name: ${username}
  namespace: iam-management
spec:
  forProvider:
    realmId: eoepca
    username: ${username}
    email: ${username}@eoepca.org
    emailVerified: true
    firstName: ${username}
    lastName: Testuser
    initialPassword:
      - temporary: false
        valueSecretRef:
          name: ${username}-user-password
          key: password
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

> Alternatively you can create this user through the Keycloak admin interface.

### 5. **Create Groups in AppHub**

Once `eric` has been created, navigate to the Application Hub admin panel: 

```bash
source ~/.eoepca/state
xdg-open "${HTTP_SCHEME}://app-hub.${INGRESS_HOST}/hub/admin"
```

- **Log in** as the `eric` user - using the password from the state file (`~/.eoepca/state`) variable `KEYCLOAK_TEST_PASSWORD`.

- Select **> Manage Groups** and create the following groups with this exact naming:

    - `group-1`
    - `group-2`
    - `group-3`

> These groups are simply examples that are configured into the default deployment. This default configuration should be adapted for your platform deployment.

![Create Groups](../img/apphub/groups.jpeg)

### 6. **Assign Users to Groups**

Individually assign the `eric` user to each group and hit **Apply**.

![Assign Users to Groups](../img/apphub/assign-users.jpeg)


### 7. **Select a Profile**

Return to the primary Application Hub interface (`https://app-hub.${INGRESS_HOST}/`) and log in as `eric`.

Selecting `Start My Server` - you should now see a list of the preconfigured profiles. Select one to spawn an application profile.

> These preconfigured profiles are simply examples that are configured into the default deployment. These default profiles should be adapted for your platform deployment.

![Select a Profile](../img/apphub/profiles.jpeg)

### 8. **Launch a Profile**

Select one of the profiles to launch a profile. You will then be redirected to the relevant tooling environment.

![Launch a Profile](../img/apphub/launch.jpeg)

---

## Validation

### 1 Automated Validation

Run validation:
```bash
bash validation.sh
```

### 2 Manual Validation

1. **Check Kubernetes Resources**:
    
```bash
kubectl get pods -n application-hub
```

Ensure the JupyterHub pod(s) and other components are in the `Running` state.
    
2. **Access the Hub**:
    
- Go to `https://app-hub.${INGRESS_HOST}/`.
- You should be redirected to Keycloak (or your chosen OIDC provider) for login if OIDC is set up.
- Upon successful login, you'll land in the JupyterHub interface (the "spawn" page).

3. **Spawn a Notebook**:

> While this Building Block is still in development, the following steps may not work as expected. This section will be updated in the future.

- If you have multiple **Profiles**, pick one.
- Wait for the container to start. You should end up in a JupyterLab interface.

If something fails (e.g. a 401 from Keycloak or a "profile list is empty" error), review the logs:

```bash
kubectl logs -n application-hub <application-hub-pod-name>
```

---

## Advanced Configuration

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