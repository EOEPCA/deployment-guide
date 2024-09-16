#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Data Access..."

# Collect user inputs
ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates (e.g., letsencrypt-prod)" "letsencrypt-prod" is_non_empty
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "DB_STORAGE_CLASS" "Specify the storage class for the database (e.g., managed-nfs-storage-retain)" "managed-nfs-storage-retain" is_non_empty
ask AWS_ENDPOINT_URL_S3 "Enter the AWS S3 endpoint URL:" "minio.${INGRESS_HOST}"

envsubst <"$TEMPLATE_PATH" >"$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"
