#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Catalogue Protection..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain for ingress hosts" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty

# Generate passwords
RC_GC_CLIENT_SECRET=$(generate_password)
RC_GC_ENCRYPTION_KEY=$(generate_password)

# Define template and output path
TEMPLATE_PATH="resource-catalogue-protection-values-template.yaml"
OUTPUT_PATH="resource-catalogue-protection-values.yaml"

# Use envsubst to substitute environment variables into template
envsubst < "$TEMPLATE_PATH" > "$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"

# Notify the user to store the generated passwords
echo ""
echo "🔐 IMPORTANT: The following passwords have been generated for your deployment:"
echo "Resource Catalogue Gatekeeper Client Secret: $RC_GC_CLIENT_SECRET"
echo "Resource Catalogue Gatekeeper Encryption Key: $RC_GC_ENCRYPTION_KEY"