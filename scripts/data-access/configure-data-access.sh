#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Data Access Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "default" is_non_empty
configure_cert

ask "S3_HOST" "Enter the S3 Host URL (excluding https)" "minio.${INGRESS_HOST}" is_non_empty
ask "S3_ACCESS_KEY" "Enter the S3 (MinIO) access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the S3 (MinIO) secret key" "" is_non_empty

# Generate configuration files
envsubst <"eoapi/values-template.yaml" >"eoapi/generated-values.yaml"
envsubst <"stacture/values-template.yaml" >"stacture/generated-values.yaml"
envsubst <"tyk-gateway/values-template.yaml" >"tyk-gateway/generated-values.yaml"
envsubst <"tyk-gateway/redis-values-template.yaml" >"tyk-gateway/redis-generated-values.yaml"
envsubst <"postgres/values-template.yaml" >"postgres/generated-values.yaml"

if [ "$USE_CERT_MANAGER" == "no" ]; then
    echo ""
    echo "📄 Since you're not using cert-manager, please create the following TLS secrets manually before deploying:"
    echo "- eoapi-tls"
    echo "- data-access-stacture-tls"
fi
