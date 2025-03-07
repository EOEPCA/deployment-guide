#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Data Access Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

ask "S3_HOST" "Enter the S3 Host URL (excluding https)" "minio.${INGRESS_HOST}" is_non_empty
ask "S3_ACCESS_KEY" "Enter the S3 (MinIO) access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the S3 (MinIO) secret key" "" is_non_empty

# Generate configuration files
envsubst <"eoapi/values-template.yaml" >"eoapi/generated-values.yaml"
envsubst <"eoapi/ingress-template.yaml" >"eoapi/generated-ingress.yaml"
envsubst <"postgres/values-template.yaml" >"postgres/generated-values.yaml"
envsubst <"eoapi-support/values-template.yaml" >"eoapi-support/generated-values.yaml" 2>/dev/null || true

if [ "$USE_CERT_MANAGER" == "no" ]; then
    echo ""
    echo "📄 Since you're not using cert-manager, please create the following TLS secrets manually before deploying:"
    echo "- eoapi-tls"
    echo "- eoapisupport-tls (if eoapi-support is used)"
fi
