#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Data Access Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty

ask "S3_HOST" "Enter the S3 Host URL (excluding https)" "minio.example.com" is_non_empty
ask "S3_ACCESS_KEY" "Enter the S3 (MinIO) access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the S3 (MinIO) secret key" "" is_non_empty

# Generate configuration files
envsubst <"eoapi/values-template.yaml" >"eoapi/generated-values.yaml"
envsubst <"stacture/values-template.yaml" >"stacture/generated-values.yaml"
envsubst <"tyk-gateway/values-template.yaml" >"tyk-gateway/generated-values.yaml"
envsubst <"tyk-gateway/redis-values-template.yaml" >"tyk-gateway/redis-generated-values.yaml"
envsubst <"postgres/values-template.yaml" >"postgres/generated-values.yaml"
