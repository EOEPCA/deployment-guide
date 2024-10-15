#!/bin/bash

echo "Configuring Minio..."
source ../common/utils.sh

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty

envsubst <"api/$TEMPLATE_PATH" >"api/$OUTPUT_PATH"
envsubst <"server/$TEMPLATE_PATH" >"server/$OUTPUT_PATH"

add_to_state_file "MINIO_USER" user
if [ -z "$MINIO_PASSWORD" ]; then
    add_to_state_file "MINIO_PASSWORD" $(generate_aes_key 32)
fi
add_to_state_file "S3_HOST" "minio.$INGRESS_HOST"
add_to_state_file "S3_ENDPOINT" "https://minio.$INGRESS_HOST"
add_to_state_file "S3_REGION" "us-east-1"

echo "✅ Configuration file generated: $OUTPUT_PATH"

echo ""
echo "🔐 IMPORTANT: The following secrets have been generated or used for your deployment:"
echo "Minio User: $MINIO_USER"
echo "Minio Password: $MINIO_PASSWORD"
echo "S3 Endpoint: $S3_ENDPOINT"
echo "S3 Region: $S3_REGION"
