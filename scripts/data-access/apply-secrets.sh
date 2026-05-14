#!/bin/bash
set -euo pipefail

# Load environment variables
source ../common/utils.sh
source "$HOME/.eoepca/state" 2>/dev/null || true

echo "Applying secrets and config for Data Access..."

# Create namespace if it doesn't exist
kubectl create namespace data-access --dry-run=client -o yaml | kubectl apply -f -

# Apply S3 credentials secret (needed for raster/multidim services)
echo "Creating S3 credentials secret..."
kubectl create secret generic data-access \
    --from-literal=AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}" \
    --namespace="data-access" \
    --dry-run=client -o yaml | kubectl apply -f -

if [ "${DATA_ACCESS_ENABLE_IAM:-no}" = "yes" ]; then
    echo "Creating STAC auth proxy filters ConfigMap..."
    kubectl create configmap stac-auth-proxy-filters \
        --from-file=eoepca_filters.py=stac-auth-proxy/eoepca_filters.py \
        --namespace=data-access \
        --dry-run=client -o yaml | kubectl apply -f -
fi

echo "Secrets and config applied successfully."