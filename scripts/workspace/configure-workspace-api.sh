#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Workspace API..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates (e.g., letsencrypt-prod)" "letsencrypt-prod" is_non_empty

ask "HARBOR_URL" "Enter the Harbor URL (e.g., harbor.$INGRESS_HOST)" "harbor.$INGRESS_HOST" is_valid_domain
ask "HARBOR_ADMIN_PASSWORD" "Enter the Harbor admin password (will be stored in a Kubernetes secret)" "" is_non_empty
ask "S3_ENDPOINT" "Enter the S3 Endpoint URL (e.g., minio.$INGRESS_HOST)" "minio.$INGRESS_HOST" is_valid_domain
ask "S3_REGION" "Enter the S3 Region" "RegionOne" is_non_empty
ask "BUCKET_ENDPOINT_URL" "Enter the Bucket Endpoint URL (e.g., http://minio-bucket-api:8080/bucket)" "http://minio-bucket-api:8080/bucket" is_non_empty

export DEFAULT_IAM_CLIENT_SECRET=$(generate_password)

# Workspace API OIDC configuration
ask "ENABLE_WORKSPACE_OIDC" "Enable OIDC for the Workspace API (true/false)" "true" is_boolean
if [ "$ENABLE_WORKSPACE_OIDC" = "true" ]; then
  ask "KEYCLOAK_URL" "Enter the Keycloak URL (e.g., identity.keycloak.$INGRESS_HOST)" "identity.keycloak.$INGRESS_HOST" is_valid_domain
  ask "IDENTITY_API_URL" "Enter the Identity API URL (e.g., identity.api.$INGRESS_HOST)" "identity.api.$INGRESS_HOST" is_non_empty
  ask "WORKSPACE_API_CLIENT_SECRET" "Enter the Keycloak client secret for workspace-api" "" is_non_empty
  export ENCRYPTION_KEY=$(generate_aes_key 32)
fi

# Create Kubernetes secret for Harbor admin password
# TODO: This didnt work so manually did kubectl create secret generic harbor   --from-literal=HARBOR_ADMIN_PASSWORD="your_harbor_admin_password"
kubectl create secret generic harbor \
  --from-literal=HARBOR_ADMIN_PASSWORD="$HARBOR_PASSWORD"

# Replace variables in the template
envsubst < "$TEMPLATE_PATH" > "$OUTPUT_PATH"
if [ "$ENABLE_WORKSPACE_OIDC" = "true" ]; then
  envsubst < "gatekeeper-template.yaml" > "gatekeeper-values.yaml"
fi


# Notify the user to store the generated secrets
echo "✅ Configuration file generated: $OUTPUT_PATH"
echo ""
echo "🔐 IMPORTANT: The following secrets have been generated or used for your deployment:"
echo "Harbor Admin Password: [Stored in Kubernetes secret 'harbor']"
echo "Default IAM Client Secret: $DEFAULT_IAM_CLIENT_SECRET"
if [ "$ENABLE_WORKSPACE_OIDC" = "true" ]; then
  echo "Workspace API Encryption Key: $ENCRYPTION_KEY"
fi
echo "Please ensure these are stored securely!"