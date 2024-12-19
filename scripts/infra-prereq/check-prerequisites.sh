#!/usr/bin/env bash

set -euo pipefail

# Configuration: update these to suit your environment
EOEPCA_DOMAIN="${EOEPCA_DOMAIN:-develop.eoepca.org}"   # Your wildcard domain (e.g. *.example.com)
TEST_NAMESPACE="eoepca-prereq-check"
TEST_POD_NAME="test-root-pod"
TEST_INGRESS_NAME="test-ingress"
TEST_SERVICE_NAME="test-service"
TEST_DEPLOYMENT_NAME="test-deployment"
TEST_SC_ANNOTATION="volume.beta.kubernetes.io/storage-class" # Adjust if needed
TEST_IMAGE="busybox:latest"
TIMEOUT=60

echo "=== EOEPCA Prerequisite Check Script ==="

# Ensure we can talk to the cluster
if ! kubectl version --client &> /dev/null; then
  echo "ERROR: kubectl not found or not configured." >&2
  exit 1
fi

# Create a temporary namespace for tests
echo "Creating temporary namespace: $TEST_NAMESPACE"
kubectl create namespace "$TEST_NAMESPACE" &> /dev/null || true

###################################
# 1. Test if pods can run as root #
###################################
echo "Testing if we can run a pod as root..."

# Attempt to run a simple pod as root. Busybox should run as root by default.
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
end=$((SECONDS+$TIMEOUT))
while true; do
  phase=$(kubectl get pod "$TEST_POD_NAME" -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}')
  if [ "$phase" = "Running" ]; then
    break
  fi
  if [ $SECONDS -ge $end ]; then
    echo "ERROR: Pod failed to run as root within ${TIMEOUT}s."
    kubectl describe pod "$TEST_POD_NAME" -n "$TEST_NAMESPACE"
    exit 1
  fi
  sleep 2
done

echo "Pod is running as root. Success!"

#########################################
# 2. Verify ingress with wildcard DNS   #
#########################################
echo "Verifying ingress and wildcard DNS..."

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

echo "Waiting for ingress to be available..."
sleep 20 # give some time for ingress rules to propagate

# Check DNS resolution
if ! command -v dig &> /dev/null; then
  echo "WARNING: 'dig' command not found, skipping DNS check."
else
  dns_ip=$(dig +short "$TEST_HOST")
  if [ -z "$dns_ip" ]; then
    echo "ERROR: DNS lookup for $TEST_HOST returned no result. Check your wildcard DNS configuration."
    exit 1
  else
    echo "DNS for $TEST_HOST resolves to: $dns_ip"
  fi
fi

# Optional: try to curl the service (requires external reachability)
# If you run this script within the cluster or from a machine that can access the ingress:
# curl_output=$(curl -sk --max-time 10 "http://$TEST_HOST")
# if [ -z "$curl_output" ]; then
#   echo "WARNING: Could not reach the ingress endpoint. Ensure your load balancer and DNS are set up correctly."
# else
#   echo "Ingress responded successfully."
# fi

##################################
# 3. Check TLS certificate validity
##################################
echo "Checking TLS certificate validity..."

# Check if a ClusterIssuer is present
cluster_issuers=$(kubectl get clusterissuers -o name || true)
if [ -z "$cluster_issuers" ]; then
  echo "WARNING: No ClusterIssuer found. For production, a ClusterIssuer (e.g. backed by Let's Encrypt) is recommended."
else
  echo "Found ClusterIssuer(s):"
  echo "$cluster_issuers"
fi

# If you have a known ClusterIssuer (e.g. "letsencrypt-prod"), you could further test by deploying a test Certificate resource.
# This is a more complex check and depends on your cluster configuration.
# For now, we’ll just warn if none found.

##########################################
# 4. Confirm storage requirements (RWX)  #
##########################################
echo "Checking storage classes for ReadWriteMany support..."

# Get storage classes
scs=$(kubectl get storageclass -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.reclaimPolicy}{"\n"}{end}' || true)
if [ -z "$scs" ]; then
  echo "WARNING: No storage classes found. You will need at least one that supports ReadWriteMany for certain EOEPCA components."
else
  echo "Available StorageClasses:"
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
  # Note: You may need to specify a particular StorageClass here if you have multiple and know which supports RWX.
  # storageClassName: <your-rwx-sc>
EOF

# Wait to see if it binds
end=$((SECONDS+$TIMEOUT))
while true; do
  phase=$(kubectl get pvc test-rwx-pvc -n "$TEST_NAMESPACE" -o jsonpath='{.status.phase}')
  if [ "$phase" = "Bound" ]; then
    echo "PVC successfully bound with ReadWriteMany. Good!"
    break
  fi
  if [ $SECONDS -ge $end ]; then
    echo "WARNING: PVC did not bind with RWX. Check if your storage supports ReadWriteMany."
    break
  fi
  sleep 2
done

###################
# Cleanup (optional)
###################
echo "Cleaning up test resources..."
kubectl delete ns "$TEST_NAMESPACE" --ignore-not-found=true &> /dev/null || true

echo "All checks complete. Review any warnings or errors above."