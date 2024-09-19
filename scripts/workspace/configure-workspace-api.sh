#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Workspace API..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates (e.g., letsencrypt-prod)" "letsencrypt-prod" is_non_empty
ask "WORKSPACE_NAMESPACE" "Enter the Kubernetes namespace for the Workspace API" "workspace" is_non_empty

ask "HARBOR_URL" "Enter the Harbor URL (e.g., harbor.example.com)" "harbor.example.com" is_valid_domain
ask "HARBOR_USERNAME" "Enter the Harbor admin username" "admin" is_non_empty
ask "HARBOR_PASSWORD" "Enter the Harbor admin password (will be stored in a Kubernetes secret)" "" is_non_empty

ask "S3_ENDPOINT" "Enter the S3 Endpoint URL (e.g., minio.example.com)" "minio.example.com" is_valid_domain
ask "S3_REGION" "Enter the S3 Region" "RegionOne" is_non_empty

ask "BUCKET_ENDPOINT_URL" "Enter the Bucket Endpoint URL (e.g., http://minio-bucket-api:8080/bucket)" "http://minio-bucket-api:8080/bucket" is_non_empty

ask "KEYCLOAK_URL" "Enter the Keycloak URL (e.g., keycloak.example.com)" "keycloak.example.com" is_valid_domain
ask "KEYCLOAK_REALM" "Enter the Keycloak Realm" "master" is_non_empty
ask "IDENTITY_API_URL" "Enter the Identity API URL (e.g., identity-api.example.com)" "identity-api.example.com" is_valid_domain
ask "WORKSPACE_API_IAM_CLIENT_ID" "Enter the Workspace API IAM Client ID in Keycloak" "workspace-api" is_non_empty

export DEFAULT_IAM_CLIENT_SECRET=$(generate_password)

# Set other variables
export WORKSPACE_API_HOST="workspace-api.$INGRESS_HOST"

# Create Kubernetes secret for Harbor admin password
kubectl -n "$WORKSPACE_NAMESPACE" create secret generic harbor \
  --from-literal=HARBOR_ADMIN_PASSWORD="$HARBOR_PASSWORD" --dry-run=client -o yaml | kubectl apply -f -

# TODO: This didnt work so manually did kubectl create secret generic harbor   --from-literal=HARBOR_ADMIN_PASSWORD="your_harbor_admin_password"

echo "Created Kubernetes secret 'harbor' in namespace '$WORKSPACE_NAMESPACE'."

# Replace variables in the template
envsubst < "$TEMPLATE_PATH" > "$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"

# Notify the user to store the generated secrets
echo ""
echo "🔐 IMPORTANT: The following secrets have been generated or used for your deployment:"
echo "Harbor Admin Password: [Stored in Kubernetes secret 'harbor']"
echo "Default IAM Client Secret: $DEFAULT_IAM_CLIENT_SECRET"
echo "Please ensure these are stored securely!"