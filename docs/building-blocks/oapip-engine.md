# Processing - OGC API Processes Engine

## Introduction

The **OGC API Processes Engine** lets users deploy, manage, and execute OGC Application Packages through a standardised API. It's built on the [ZOO-Project](https://zoo-project.github.io/docs/intro.html#what-is-zoo-project) `zoo-project-dru` implementation, which supports OGC WPS 1.0.0/2.0.0 and OGC API Processes Parts 1 & 2.

The engine supports multiple execution backends depending on your infrastructure:

| Execution Engine | Backend | Best For |
| --- | --- | --- |
| **Calrissian** | Kubernetes jobs in dedicated namespaces | Pure Kubernetes environments |
| **Toil** | HPC batch schedulers (HTCondor, Slurm, PBS, LSF, etc.) | Hybrid Kubernetes + HPC environments |

Both backends use the same OGC API Processes interface - the difference is where the actual computation runs.

---

## Prerequisites

### Common Requirements

| Component        | Requirement                            | Documentation Link                                                                            |
| ---------------- | -------------------------------------- | --------------------------------------------------------------------------------------------- |
| Kubernetes       | Cluster (tested on v1.32)              | [Installation Guide](../prerequisites/kubernetes.md)                                         |
| Helm             | Version 3.5 or newer                   | [Installation Guide](https://helm.sh/docs/intro/install/)                                     |
| kubectl          | Configured for cluster access          | [Installation Guide](https://kubernetes.io/docs/tasks/tools/)                                 |
| Ingress          | Properly installed                     | [Installation Guide](../prerequisites/ingress/overview.md) |
| TLS Certificates | Managed via `cert-manager` or manually | [TLS Certificate Management Guide](../prerequisites/tls.md)                             |
| Stage-In S3      | Accessible                             | [MinIO Deployment Guide](../prerequisites/minio.md)                                          |
| Stage-Out S3     | Accessible                             | [MinIO Deployment Guide](../prerequisites/minio.md)                                          |

### Calrissian-Specific Requirements

No additional requirements beyond the common prerequisites. Calrissian runs CWL workflows as Kubernetes jobs, so everything stays within your cluster.

### Toil/HPC-Specific Requirements

You'll need an HPC cluster with:

- Container support ([Docker](https://www.docker.com/) or [Apptainer/Singularity](https://apptainer.org/))
- Internet access from compute nodes (or local container registries and data repositories)
- A [Toil WES service](https://toil.readthedocs.io/en/master/running/server/wes.html) endpoint

Toil supports several batch schedulers: [HTCondor](https://research.cs.wisc.edu/htcondor/), [Slurm](https://www.schedmd.com/), [PBS/Torque/PBS Pro](#TODO) [LSF](https://en.wikipedia.org/wiki/Platform_LSF), and [Grid Engine](http://www.univa.com/oracle).

#### Setting up a Local HTCondor (Development/Testing Only)

> **Warning:** This setup is for development and testing purposes only. Do not use this in production - use your organisation's HPC infrastructure instead.

If you don't have access to an HPC cluster and want to test the Toil integration locally, you can install [MiniHTCondor](https://htcondor.org/), a single-node HTCondor package designed for testing.

**Install HTCondor using the official script:**
```bash
# Download and run the HTCondor installer (installs minicondor by default)
curl -fsSL https://get.htcondor.org | sudo /bin/bash -s -- --no-dry-run

# Verify HTCondor is running
condor_status
```

You should see output showing your local machine as a condor slot. If `condor_status` returns an error, check that the condor service is running:
```bash
sudo systemctl status condor
```

**Configure Docker for HTCondor jobs:**

HTCondor needs to run containers for CWL workflows. Add your user to the docker group and create a wrapper to mount `/etc/hosts` for DNS resolution:

```bash
# Add your user to the docker group
sudo usermod -a -G docker $USER

# Create a docker wrapper for DNS resolution in containers
sudo tee /usr/local/bin/docker > /dev/null << 'EOF'
#!/usr/bin/python3
import sys, os
n = sys.argv
n[0] = "/usr/bin/docker"
if "run" in n:
    n.insert(n.index("run") + 1, "-v=/etc/hosts:/etc/hosts:ro")
os.execv(n[0], n)
EOF
sudo chmod +x /usr/local/bin/docker

# Log out and back in for the docker group change to take effect
```

After logging back in, verify HTCondor can see your machine:
```bash
condor_status
```

#### Setting up Toil WES

> **Already have a Toil WES service?** Skip to [Clone the Deployment Guide Repository](#clone-the-deployment-guide-repository).

If you need to set up Toil WES on your HPC cluster (or local MiniCondor), follow these steps. The examples use HTCondor, but the process is similar for other schedulers.

**Install Toil**

Install Toil in a Python virtual environment on storage accessible to all compute nodes:
```bash
# Create directories for Toil venv and job storage
mkdir -p ~/toil ~/toil/storage
python3 -m venv --prompt toil ~/toil/venv

# Activate and install Toil with required extras
source ~/toil/venv/bin/activate
python3 -m pip install toil[cwl,htcondor,server,aws] htcondor
```

> **Note:** Replace `htcondor` with your batch system if different (e.g., `toil[cwl,slurm,server,aws]` for Slurm).

**Test the Installation**

Run a sample CWL workflow to verify everything works:
```bash
source ~/toil/venv/bin/activate

# Download a test application
wget https://github.com/EOEPCA/deployment-guide/raw/refs/heads/main/scripts/processing/oapip/examples/convert-url-app.cwl

# Create test directories and parameters
jobid=$(uuidgen)
mkdir -p ~/toil/storage/test/{work_dir,job_store}
cat <<EOF > ~/toil/storage/test/work_dir/$jobid.params.yaml
fn: resize
url: https://eoepca.org/media_portal/images/logo6_med.original.png
size: 50%
EOF

# Run the test (adjust --batchSystem for your scheduler)
toil-cwl-runner \
    --batchSystem htcondor \
    --workDir ~/toil/storage/test/work_dir \
    --jobStore ~/toil/storage/test/job_store/$jobid \
    convert-url-app.cwl#convert-url \
    ~/toil/storage/test/work_dir/$jobid.params.yaml
```

If successful, you'll see JSON output representing a STAC Item. Clean up:
```bash
rm -rf ~/toil/storage/test convert-url-app.cwl
```

**Start the Toil WES Service**

The WES service needs RabbitMQ for job queuing and Celery for queue management.

Start RabbitMQ:

```bash
docker run -d --restart=always --name toil-wes-rabbitmq -p 127.0.0.1:5672:5672 rabbitmq:alpine
```

Start Celery:

```bash
source ~/toil/venv/bin/activate
celery --broker=amqp://guest:guest@127.0.0.1:5672// -A toil.server.celery_app multi start w1 \
   --loglevel=INFO --pidfile=$HOME/celery.pid --logfile=$HOME/celery.log
```

Start the Toil WES server:

```bash
source ~/toil/venv/bin/activate
mkdir -p $HOME/toil/storage/workdir $HOME/toil/storage/workflows

TOIL_WES_BROKER_URL=amqp://guest:guest@127.0.0.1:5672// nohup toil server \
    --host 0.0.0.0 \
    --work_dir $HOME/toil/storage/workflows \
    --opt=--batchSystem=htcondor \
    --opt=--workDir=$HOME/toil/storage/workdir \
    --logFile $HOME/toil.log \
    --logLevel INFO \
    -w 1 &>$HOME/toil_run.log </dev/null &

echo "$!" > $HOME/toil.pid
sleep 5
```

> **Note:** Adjust `--batchSystem=htcondor` to match your scheduler.

**Verify the WES Service**

```bash
curl -s http://localhost:8080/ga4gh/wes/v1/service-info | jq
```

You should see JSON service information. Your WES endpoint URL will be:
```
http://<your-hpc-host>:8080/ga4gh/wes/v1/
```

## Clone the Deployment Guide Repository
```bash
git clone https://github.com/EOEPCA/deployment-guide
cd deployment-guide/scripts/processing/oapip
```

Validate your environment:
```bash
bash check-prerequisites.sh
```

---

## Deployment

### Run the Configuration Script
```bash
bash configure-oapip.sh
```

### Common Configuration Parameters

- **`INGRESS_HOST`**: Base domain for ingress hosts.
    - *Example*: `example.com`
- **`CLUSTER_ISSUER`** (if using `cert-manager`): Name of the ClusterIssuer.
    - *Example*: `letsencrypt-http01-apisix`
- **`PERSISTENT_STORAGECLASS`**: Storage class for persistent volumes.
    - *Example*: `standard`

### Workspace Integration

The engine supports two options for stage-out of processing results:

* **With the EOEPCA+ Workspace BB** - results go directly to the user's workspace bucket
* **With a dedicated S3 bucket** - results go to a pre-configured shared bucket

This is controlled by:

- **`USE_WORKSPACE_API`**: Set to `true` to integrate with user Workspace storage

If using Workspace integration:

* The Workspace BB must already be deployed
* The username from the JWT Bearer token (or path prefix for open services) determines which workspace bucket to use, following the `ws-<username>` naming convention

### Stage-Out S3 Configuration

Ensure you have an S3-compatible object store set up. See the [MinIO Deployment Guide](../prerequisites/minio.md) if needed.

- **`S3_ENDPOINT`**, **`S3_ACCESS_KEY`**, **`S3_SECRET_KEY`**, **`S3_REGION`**: Credentials for Stage-Out storage

### Stage-In S3 Configuration

If your input data is hosted separately from output storage:

- **`STAGEIN_S3_ENDPOINT`**, **`STAGEIN_S3_ACCESS_KEY`**, **`STAGEIN_S3_SECRET_KEY`**, **`STAGEIN_S3_REGION`**

### OIDC Configuration

> **Note:** The EOEPCA OIDC protection requires the **APISIX** Ingress Controller. If you're using a different ingress controller, OIDC will not be available and you can skip this configuration.

If using APISIX, you can enable OIDC authentication during configuration. When prompted for the `Client ID`, we recommend `oapip-engine`.

See the [IAM Building Block](./iam/main-iam.md) guide for IAM setup, and [Enable OIDC with Keycloak](#optional-enable-oidc-with-keycloak) below for post-deployment configuration.

### Calrissian Configuration

When prompted for execution engine, select `calrissian`. You'll need to configure:

- **`NODE_SELECTOR_KEY`**: Determines which nodes run processing workflows
    - *Example*: `kubernetes.io/os`
    - *Read more*: [Node Selector Documentation](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector)
- **`NODE_SELECTOR_VALUE`**: Value for the node selector
    - *Example*: `linux`

### Toil Configuration

When prompted for execution engine, select `toil`. You'll need to configure:

- **`OAPIP_TOIL_WES_URL`**: Your Toil WES endpoint, must end with `/ga4gh/wes/v1/`
    - *Example*: `http://192.168.1.100:8080/ga4gh/wes/v1/`
    - *Read more*: [Zoo WES Runner documentation](https://zoo-project.github.io/zoo-wes-runner/)
- **`OAPIP_TOIL_WES_USER`**: WES service username
    - *Example*: `test`
- **`OAPIP_TOIL_WES_PASSWORD`**: WES service password (htpasswd format)
    - *Example*: `$2y$12$ci.4U63YX83CwkyUrjqxAucnmi2xXOIlEF6T/KdP9824f1Rf1iyNG`

> **Note:** If you set up Toil WES without authentication (as in the setup guide above), use placeholder credentials - they'll be ignored.

> **Important: Network Reachability**
> 
> The WES URL must be reachable from within the Kubernetes cluster.
> 
> - If Toil runs on the same machine as Kubernetes, use the host's IP address (e.g., `http://192.168.1.100:8080/ga4gh/wes/v1/`)
> - If Toil runs on a separate HPC system, ensure network routing and firewall rules allow traffic from the Kubernetes pod network to the WES endpoint
> 
> You can verify connectivity from within the cluster:
> ```bash
> kubectl run -it --rm debug --image=alpine --restart=Never -- \
>   wget -qO- http://<your-wes-host>:8080/ga4gh/wes/v1/service-info
> ```

### Deploy the Helm Chart
```bash
helm repo add zoo-project https://zoo-project.github.io/charts/
helm repo update zoo-project
```

```bash
helm upgrade -i zoo-project-dru zoo-project/zoo-project-dru \
  --version 0.8.3 \
  --values generated-values.yaml \
  --namespace processing \
  --create-namespace
```

---

## Optional: Enable OIDC with Keycloak

> This requires the **APISIX** Ingress Controller. If you're using a different Ingress Controller, skip to [Validation](#validation).

Skip this section if you don't need IAM protection right now - the engine will work, just without access restrictions.

To protect OAPIP endpoints with Keycloak tokens and policies, follow these steps after enabling OIDC in the configuration script.

> First, ensure you've followed the [IAM Deployment Guide](./iam/main-iam.md) and have Keycloak running.

### Create a Keycloak Client
```bash
source ~/.eoepca/state
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${OAPIP_CLIENT_ID}-keycloak-client
  namespace: iam-management
stringData:
  client_secret: ${OAPIP_CLIENT_SECRET}
---
apiVersion: openidclient.keycloak.m.crossplane.io/v1alpha1
kind: Client
metadata:
  name: ${OAPIP_CLIENT_ID}
  namespace: iam-management
spec:
  forProvider:
    realmId: ${REALM}
    clientId: ${OAPIP_CLIENT_ID}
    name: Processing OAPIP Engine
    description: Processing OAPIP Engine OIDC
    enabled: true
    accessType: CONFIDENTIAL
    rootUrl: ${HTTP_SCHEME}://zoo.${INGRESS_HOST}
    baseUrl: ${HTTP_SCHEME}://zoo.${INGRESS_HOST}
    adminUrl: ${HTTP_SCHEME}://zoo.${INGRESS_HOST}
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
      name: ${OAPIP_CLIENT_ID}-keycloak-client
      key: client_secret
  providerConfigRef:
    name: provider-keycloak
    kind: ProviderConfig
EOF
```

### Protect the User's Processing Context

The ZOO-Project uses a path prefix to establish user context (e.g., `/<username>/ogc-api/processes/...`). You can protect this so only the owning user can access it.

This example protects the context for `eoepcauser` (see [Create Test Users](./iam/main-iam.md#6-create-test-users)):
```bash
source ~/.eoepca/state
export OAPIP_USER="${KEYCLOAK_TEST_USER}"
envsubst < protect-oapip-user.yaml | kubectl apply -f -
```

This creates: `eoepcauser-group`, `eoepcauser-membership`, `eoepcauser-resource`, `eoepcauser-policy`, `eoepcauser-access`.

### Create APISIX Route Ingress
```bash
kubectl apply -f generated-ingress.yaml
```

### Confirm Protection

> Wait for the ingress and TLS to be established first.
```bash
bash resource-protection-validation.sh
```

If you see `401 Authorization` errors when using a valid token, check your token and resource protection configuration.

For more detailed testing, see [Resource Protection with Keycloak Policies](./iam/advanced-iam.md#resource-protection-with-keycloak-policies).

---

## Validation

### Automated Validation
```bash
bash validation.sh
```

### Web Endpoints

Check these are accessible:

* **ZOO-Project Swagger UI** - `https://zoo.${INGRESS_HOST}/swagger-ui/oapip/`
* **OGC API Processes Landing Page** - `https://zoo.${INGRESS_HOST}/ogc-api/processes/`

### Expected Kubernetes Resources
```bash
kubectl get pods -n processing
```

All pods should be `Running` with no `CrashLoopBackOff` or `Error` states.

### Using the API

This walkthrough covers deploying, executing, monitoring, and retrieving results from a sample application.

> **Prefer a notebook?** Run `../../../notebooks/run.sh` and open the <a href="http://localhost:8888/lab/tree/oapip/oapip.ipynb" target="_blank">OAPIP Engine Validation notebook</a> at `http://localhost:8888`.

#### Initialise Environment
```bash
bash -l
source ~/.eoepca/state
```

If OIDC is enabled, generate a token:
```bash
source oapip-utils.sh
```

> **Note:** Tokens are short-lived. Re-run this if later commands fail unexpectedly.

#### List Processes
```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

#### Deploy Process `convert`
```bash
curl --silent --show-error \
  -X POST "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d @- <<EOF | jq
{
  "executionUnit": {
    "href": "https://raw.githubusercontent.com/EOEPCA/deployment-guide/refs/heads/main/scripts/processing/oapip/examples/convert-url-app.cwl",
    "type": "application/cwl"
  }
}
EOF
```

Verify it's deployed:
```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes/convert-url" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

#### Execute Process `convert`
```bash
JOB_ID=$(
  curl --silent --show-error \
    -X POST "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes/convert-url/execution" \
    ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Prefer: respond-async" \
    -d @- <<EOF | jq -r '.jobID'
  {
    "inputs": {
      "fn": "resize",
      "url":  "https://eoepca.org/media_portal/images/logo6_med.original.png",
      "size": "50%"
    }
  }
EOF
)

echo "JOB ID: ${JOB_ID}"
```

#### Check Execution Status
```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/jobs/${JOB_ID}" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

The `status` field shows `running`, `successful`, or `failed`.

#### Check Execution Results

Once the job completes successfully:
```bash
curl --silent --show-error \
  -X GET "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/jobs/${JOB_ID}/results" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

#### Undeploy Process `convert`
```bash
curl --silent --show-error \
  -X DELETE "${OAPIP_HOST}/${OAPIP_USER}/ogc-api/processes/convert-url" \
  ${OAPIP_AUTH_HEADER:+-H "$OAPIP_AUTH_HEADER"} \
  -H "Accept: application/json" | jq
```

### Monitoring Jobs on HPC (Toil only)

When using Toil, you can also monitor jobs directly on the HPC cluster:

**Toil WES logs:**
```bash
tail -n 20 ~/celery.log
```

**HPC queue status:**

For HTCondor:
```bash
condor_q -all
```

For Slurm:
```bash
squeue -u $USER
```

---

## Uninstallation

### Remove the OAPIP Engine
```bash
source ~/.eoepca/state
export OAPIP_USER="${KEYCLOAK_TEST_USER}"
kubectl delete -f generated-ingress.yaml
envsubst < protect-oapip-user.yaml | kubectl delete -f -
kubectl -n iam-management delete client.openidclient.keycloak.m.crossplane.io ${OAPIP_CLIENT_ID}
kubectl -n iam-management delete secret ${OAPIP_CLIENT_ID}-keycloak-client
helm -n processing uninstall zoo-project-dru
kubectl delete ns processing
```

### Stop Toil WES (Toil only)

If you set up Toil WES on your HPC cluster:
```bash
# Stop Toil server
kill $(cat $HOME/toil.pid)

# Stop Celery
celery --broker=amqp://guest:guest@127.0.0.1:5672// -A toil.server.celery_app multi stop w1 \
   --pidfile=$HOME/celery.pid

# Stop RabbitMQ
docker stop toil-wes-rabbitmq
docker rm toil-wes-rabbitmq
```

---

## Further Reading

**General:**

- [ZOO-Project DRU Helm Chart](https://github.com/ZOO-Project/ZOO-Project/tree/master/docker/kubernetes/helm/zoo-project-dru)
- [EOEPCA+ Deployment Guide Repository](https://github.com/EOEPCA/deployment-guide)
- [OGC API Processes Standards](https://www.ogc.org/standards/ogcapi-processes)
- [Common Workflow Language (CWL)](https://www.commonwl.org/)

**Calrissian:**

- [Calrissian Documentation](https://github.com/Duke-GCB/calrissian)
- [EOEPCA+ Cookiecutter Template](https://github.com/EOEPCA/eoepca-proc-service-template)

**Toil:**

- [Toil Documentation](https://toil.ucsc-cgl.org/)
- [Toil WES Server Documentation](https://toil.readthedocs.io/en/master/running/server/wes.html)
- [Zoo WES Runner Documentation](https://zoo-project.github.io/zoo-wes-runner/)
- [EOEPCA+ Cookiecutter Template (WES)](https://github.com/EOEPCA/eoepca-proc-service-template-wes)

---

## Feedback

If you have any issues or suggestions, please open an issue on the [EOEPCA+ Deployment Guide GitHub Repository](https://github.com/EOEPCA/deployment-guide/issues).