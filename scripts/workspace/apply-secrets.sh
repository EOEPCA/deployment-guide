#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."

kubectl create namespace workspace

# Check HARBOR_ADMIN_PASSWORD is set
if [ -z "$HARBOR_ADMIN_PASSWORD" ]; then
  echo "❌ HARBOR_ADMIN_PASSWORD is not set. Please set it in the state file."
  exit 1
fi

kubectl create secret generic harbor-admin-password \
  --from-literal=HARBOR_ADMIN_PASSWORD="$HARBOR_ADMIN_PASSWORD" \
  --namespace workspace \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic minio-secret \
  --from-literal=AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
  --from-literal=AWS_ENDPOINT_URL="$S3_ENDPOINT" \
  --from-literal=AWS_REGION="$S3_REGION" \
  --namespace workspace \
  --dry-run=client -o yaml | kubectl apply -f -

if [ -z "$OIDC_WORKSPACE_ENABLED" ]; then
  kubectl create secret generic workspace-api-client \
    --from-literal=client_id="$WORKSPACE_CLIENT_ID" \
    --from-literal=client_secret="$WORKSPACE_CLIENT_SECRET" \
    --namespace workspace \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "✅ Secrets applied."
