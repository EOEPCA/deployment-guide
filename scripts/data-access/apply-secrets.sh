#!/bin/bash

# Load environment variables
source ../common/utils.sh
source "$HOME/.eoepca/state" 2>/dev/null || true

echo "Applying secrets for Data Access..."

# Create namespace if it doesn't exist
kubectl create namespace data-access --dry-run=client -o yaml | kubectl apply -f -

# Apply S3 credentials secret (always needed for raster/multidim services)
echo "Creating S3 credentials secret..."
kubectl create secret generic data-access \
    --from-literal=AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
    --namespace="data-access" \
    --dry-run=client -o yaml | kubectl apply -f -

# If using SealedSecrets, create the sealed version as well
if kubectl get crd sealedsecrets.bitnami.com >/dev/null 2>&1; then
    echo "SealedSecrets detected. Creating sealed secret..."
    
    # Check if kubeseal is installed
    if command -v kubeseal >/dev/null 2>&1; then
        kubectl create secret generic data-access \
            --from-literal=AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
            --from-literal=AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
            --namespace="data-access" \
            --dry-run=client -o yaml | \
        kubeseal -o yaml \
            --controller-name sealed-secrets \
            --controller-namespace infra > ss-data-access.yaml
        
        kubectl apply -f ss-data-access.yaml
        echo "SealedSecret created and applied"
    else
        echo "Warning: kubeseal not found. Skipping SealedSecret creation."
    fi
fi

echo "Secrets applied successfully!"
