#!/bin/bash

source ../common/utils.sh

# Exit immediately if a command fails
set -euo pipefail

###################
# Cleanup on exit
###################
cleanUp() {
  echo "Cleaning up test resources..."
  kubectl delete ns "$TEST_NAMESPACE" --ignore-not-found=true &>/dev/null || true
  echo "All checks complete. Review any warnings or errors above."
}
trap cleanUp EXIT

# Inputs needed for the checks
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for ReadWriteMany persistent volumes" "standard" is_non_empty

# Configuration: update these to suit your environment
EOEPCA_DOMAIN="${INGRESS_HOST}"
TEST_NAMESPACE="eoepca-prereq-check"
TEST_POD_NAME="test-root-pod"
TEST_INGRESS_NAME="test-ingress"
TEST_SERVICE_NAME="test-service"
TEST_DEPLOYMENT_NAME="test-deployment"
TEST_IMAGE="busybox:latest"
TIMEOUT=60

echo "=== EOEPCA Prerequisite Check Script ==="
echo "Using EOEPCA_DOMAIN=$EOEPCA_DOMAIN"
echo "Launching tests in namespace '$TEST_NAMESPACE'..."

# Ensure we can talk to the cluster
if ! kubectl version --client &>/dev/null; then
  echo "ERROR: kubectl not found or not configured."
  exit 1
fi

# Create a temporary namespace for tests
echo "Creating temporary namespace: $TEST_NAMESPACE"
kubectl create namespace "$TEST_NAMESPACE" &>/dev/null || true

###################################
# 1. Test if pods can run as root #
###################################
echo "1) Testing if we can run a pod as root..."

# Attempt to run a simple pod as root.
cat <<EOF | kubectl apply -n "$TEST_NAMESPACE" -f -
apiVersion: v1
kind: Pod
metadata:
  name: $TEST_POD_NAME
spec:
  containers:
    - name: test
      image: $TEST_IMAGE
      command: ["sh", "-c", "id && sleep 30"]
      securityContext:
        runAsUser: 0
  restartPolicy: Never
EOF

# Wait for the pod to become Running
end=$((SECONDS + TIMEOUT))
while true; do
  phase=$(kubectl get pod "$TEST_POD_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [ "$phase" = "Running" ]; then
    echo "   Pod '$TEST_POD_NAME' is Running as root. Success!"
    break
  fi
  if [ $SECONDS -ge $end ]; then
    echo "ERROR: Pod failed to run as root within ${TIMEOUT}s."
    kubectl describe pod "$TEST_POD_NAME" -n "$TEST_NAMESPACE"
    exit 1
  fi
  sleep 2
done

#########################################
# 2. Verify ingress with wildcard DNS   #
#########################################
echo "2) Verifying ingress and wildcard DNS..."

# Deploy a simple test application (e.g. a small HTTP echo server)
cat <<EOF | kubectl apply -n "$TEST_NAMESPACE" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $TEST_DEPLOYMENT_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
        - name: test-app
          image: kennethreitz/httpbin
          ports:
            - containerPort: 80
EOF

cat <<EOF | kubectl apply -n "$TEST_NAMESPACE" -f -
apiVersion: v1
kind: Service
metadata:
  name: $TEST_SERVICE_NAME
spec:
  selector:
    app: test-app
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
EOF

# Wait for deployment to be ready
kubectl rollout status deployment/$TEST_DEPLOYMENT_NAME -n "$TEST_NAMESPACE" --timeout=90s

# Create an Ingress to test wildcard domain
TEST_HOST="test.$EOEPCA_DOMAIN"
cat <<EOF | kubectl apply -n "$TEST_NAMESPACE" -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $TEST_INGRESS_NAME
spec:
  rules:
    - host: $TEST_HOST
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: $TEST_SERVICE_NAME
                port:
                  number: 80
EOF

echo "   Waiting for ingress to be available..."
sleep 30 # Give some time for ingress rules to propagate

# Check DNS resolution using ANY record so that if there's a CNAME -> A chain, we still see it.
if ! command -v dig &>/dev/null; then
  echo "WARNING: 'dig' command not found, skipping DNS check."
else
  dns_output=$(dig +short ANY "$TEST_HOST")
  if [ -z "$dns_output" ]; then
    echo "ERROR: DNS lookup for $TEST_HOST returned no result."
    echo "       Check your wildcard DNS configuration (or create a DNS record if needed)."
    exit 1
  else
    echo "   DNS resolution for $TEST_HOST returned:"
    echo "$dns_output"
    echo "   This indicates that $TEST_HOST does resolve (even if via CNAME)."
  fi
fi

# Try to curl the service (requires external reachability)
echo "   Attempting to curl http://$TEST_HOST ..."
curl_output=$(curl -sk --max-time 10 "http://$TEST_HOST" || true)
if [ -z "$curl_output" ]; then
  echo "WARNING: Could not reach the ingress endpoint. This can happen if:"
  echo "  - Your load balancer and DNS aren't yet fully set up."
  echo "  - The script is running from an environment without external routing to the cluster."
  echo "  - The Ingress isn't properly exposed externally."
else
  echo "Ingress responded successfully (HTTP content received)."
fi

##################################
# 3. Check TLS certificate validity
##################################
echo "3) Checking TLS certificate validity (ClusterIssuer presence)..."

# Check if a ClusterIssuer is present
cluster_issuers=$(kubectl get clusterissuers -o name 2>/dev/null || true)
if [ -z "$cluster_issuers" ]; then
  echo "WARNING: No ClusterIssuer found. For production, a ClusterIssuer (e.g. backed by Let's Encrypt) is recommended."
else
  echo "   Found ClusterIssuer(s):"
  echo "$cluster_issuers"
fi

# (Optional) If you want to validate issuance further, you would create a Certificate
# resource referencing the ClusterIssuer. This is cluster-specific, so we leave it out here.

##########################################
# 4. Confirm storage requirements (RWX)  #
##########################################
echo "4) Checking storage classes for ReadWriteMany support..."

# Get storage classes
scs=$(kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.reclaimPolicy}{"\n"}{end}' 2>/dev/null || true)
if [ -z "$scs" ]; then
  echo "WARNING: No storage classes found. You will need at least one that supports ReadWriteMany."
else
  echo "   Available StorageClasses:"
  echo "$scs"
fi

# Attempt to create a PVC with RWX access mode and see if it binds
cat <<EOF | kubectl apply -n "$TEST_NAMESPACE" -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-rwx-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: $STORAGE_CLASS
EOF

# Wait to see if it binds
end=$((SECONDS + TIMEOUT))
while true; do
  phase=$(kubectl get pvc test-rwx-pvc -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [ "$phase" = "Bound" ]; then
    echo "   PVC 'test-rwx-pvc' successfully bound with ReadWriteMany. Good!"
    kubectl get pvc test-rwx-pvc -n "$TEST_NAMESPACE"
    break
  fi
  if [ $SECONDS -ge $end ]; then
    echo "WARNING: PVC did not bind with RWX. Either there's no RWX support or it needs more time."
    break
  fi
  sleep 2
done
