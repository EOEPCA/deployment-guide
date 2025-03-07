#!/bin/bash

echo "Configuring MinIO..."
source ../common/utils.sh

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

# Save state
add_to_state_file "MINIO_USER" "user"
if [ -z "$MINIO_PASSWORD" ]; then
    MINIO_PASSWORD="$(generate_aes_key 32)"
    add_to_state_file "MINIO_PASSWORD" "$MINIO_PASSWORD"
fi
add_to_state_file "S3_HOST" "minio.$INGRESS_HOST"
add_to_state_file "S3_ENDPOINT" "$HTTP_SCHEME://minio.$INGRESS_HOST"
add_to_state_file "S3_REGION" "us-east-1"

# Generate configuration files
gomplate  -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ Configuration files generated:"
echo "- generated-values.yaml"

echo ""
echo "🔐 IMPORTANT: The following secrets have been generated or used for your deployment:"
echo "MinIO User: user"
echo "MinIO Password: $MINIO_PASSWORD"
echo "S3 Endpoint: $S3_ENDPOINT"
echo "S3 Region: us-east-1"
