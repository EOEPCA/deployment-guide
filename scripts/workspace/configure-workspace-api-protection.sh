#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Workspace API Protection (Identity Gatekeeper)..."

# Collect user inputs
ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates (e.g., letsencrypt-prod)" "letsencrypt-prod" is_non_empty
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "WORKSPACE_NAMESPACE" "Enter the Kubernetes namespace where the Workspace API is deployed" "workspace" is_non_empty
ask "KEYCLOAK_URL" "Enter the Keycloak URL (e.g., https://keycloak.example.com)" "https://keycloak.example.com" is_valid_url
ask "WORKSPACE_API_CLIENT_ID" "Enter the Workspace API Client ID in Keycloak" "workspace-api" is_non_empty

# Generate secrets if not provided
export WORKSPACE_API_CLIENT_SECRET=$(generate_password)
export ENCRYPTION_KEY=$(generate_aes_key 32)

# Set other variables
export WORKSPACE_API_HOST="workspace-api.$INGRESS_HOST"

# Define paths
TEMPLATE_PATH="workspace-api-protection-values.yaml.template"
OUTPUT_PATH="generated-workspace-api-protection-values.yaml"

# Replace variables in the template
envsubst < "$TEMPLATE_PATH" > "$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"

# Notify the user to store the generated secrets
echo ""
echo "🔐 IMPORTANT: The following secrets have been generated for your deployment:"
echo "Workspace API Client Secret: $WORKSPACE_API_CLIENT_SECRET"
echo "Encryption Key: $ENCRYPTION_KEY"
echo "Please ensure these are stored securely!"