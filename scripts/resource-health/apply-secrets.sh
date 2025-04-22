#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh

NAMESPACE="resource-health"

echo "Applying Kubernetes secrets for Resource Health..."

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# IAM Client credentials for OIDC
kubectl create secret generic resource-health-iam-client-credentials \
  --from-literal=client_id="$RESOURCE_HEALTH_CLIENT_ID" \
  --from-literal=client_secret="$RESOURCE_HEALTH_CLIENT_SECRET" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Resource Health secrets applied."