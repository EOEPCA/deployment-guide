#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Workspace Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty

# S3 configuration
ask "S3_ENDPOINT" "Enter the S3 endpoint URL" "https://minio.example.com" is_non_empty
ask "S3_REGION" "Enter the S3 region" "us-east-1" is_non_empty
ask "S3_ACCESS_KEY" "Enter the MinIO access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the MinIO secret key" "" is_non_empty

if [ -z "$WORKSPACE_UI_PASSWORD" ]; then
    add_to_state_file "WORKSPACE_UI_PASSWORD" $(generate_aes_key 32)
fi

# Generate configuration files
envsubst <"workspace-api/values-template.yaml" >"workspace-api/generated-values.yaml"
envsubst <"workspace-ui/values-template.yaml" >"workspace-ui/generated-values.yaml"
envsubst <"workspace-admin/values-template.yaml" >"workspace-admin/generated-values.yaml"

echo "Please proceed to apply the necessary Kubernetes secrets before deploying."


echo ""
echo "🔐 IMPORTANT: The following secrets have been generated or used for your deployment:"
echo "Workspace UI Password: $WORKSPACE_UI_PASSWORD"
echo ""
