#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."

kubectl create namespace workspace --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic minio-secret \
  --from-literal=AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
  --from-literal=AWS_ENDPOINT_URL="$S3_ENDPOINT" \
  --from-literal=AWS_REGION="$S3_REGION" \
  --namespace workspace \
  --dry-run=client -o yaml | kubectl apply -f -

# Create wildcard TLS certificate secret for Educates
kubectl create secret generic workspace-tls \
  --from-literal=tls.crt="" \
  --from-literal=tls.key="" \
  --namespace workspace \
  --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

# Workspace API Keycloak client credentials
if [ "$OIDC_WORKSPACE_ENABLED" == "true" ]; then
  kubectl create secret generic workspace-api \
    --from-literal=client_id="$WORKSPACE_API_CLIENT_ID" \
    --from-literal=client_secret="$WORKSPACE_API_CLIENT_SECRET" \
    --from-literal=credentials="$(cat <<EOF
{
  "client_id": "$WORKSPACE_API_CLIENT_ID",
  "client_secret": "$WORKSPACE_API_CLIENT_SECRET",
  "url": "http://iam-keycloak.iam",
  "base_path": "/",
  "realm": "$REALM",
  "root_ca_certificate" : "" 
}
EOF
)" \
    --namespace workspace \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# Workspace Pipelines Keycloak client credentials
if [ "$OIDC_WORKSPACE_ENABLED" == "true" ]; then
  kubectl create secret generic keycloak-secret \
    --from-literal=client_id="$WORKSPACE_PIPELINE_CLIENT_ID" \
    --from-literal=client_secret="$WORKSPACE_PIPELINE_CLIENT_SECRET" \
    --from-literal=credentials="$(cat <<EOF
{
  "client_id": "$WORKSPACE_PIPELINE_CLIENT_ID",
  "client_secret": "$WORKSPACE_PIPELINE_CLIENT_SECRET",
  "url": "http://iam-keycloak.iam",
  "base_path": "/",
  "realm": "$REALM",
  "root_ca_certificate" : "" 
}
EOF
)" \
    --namespace workspace \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "✅ Secrets applied."
