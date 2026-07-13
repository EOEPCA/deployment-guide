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

# Workspace Pipeline Keycloak client credentials (required unconditionally, see step 7)
kubectl create secret generic workspace-pipeline-keycloak-client \
  --from-literal=client_secret="$WORKSPACE_PIPELINE_CLIENT_SECRET" \
  --namespace iam-management \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic workspace-pipeline-client \
  --from-literal=credentials="{\"client_id\":\"$WORKSPACE_PIPELINE_CLIENT_ID\",\"client_secret\":\"$WORKSPACE_PIPELINE_CLIENT_SECRET\",\"url\":\"$HTTP_SCHEME://$KEYCLOAK_HOST\",\"base_path\":\"\",\"realm\":\"$REALM\"}" \
  --namespace workspace \
  --dry-run=client -o yaml | kubectl apply -f -

# Workspace API Keycloak client credentials (required unconditionally, see step 9.1)
kubectl create secret generic ${WORKSPACE_API_CLIENT_ID}-keycloak-client \
  --from-literal=client_secret="$WORKSPACE_API_CLIENT_SECRET" \
  --namespace iam-management \
  --dry-run=client -o yaml | kubectl apply -f -

# Only referenced by the ingress openid-connect plugin and Datalab session SSO
if [ "$OIDC_WORKSPACE_ENABLED" == "true" ]; then
  kubectl create secret generic workspace-api-keycloak-client \
    --from-literal=client_id="$WORKSPACE_API_CLIENT_ID" \
    --from-literal=client_secret="$WORKSPACE_API_CLIENT_SECRET" \
    --namespace workspace \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "✅ Secrets applied."
