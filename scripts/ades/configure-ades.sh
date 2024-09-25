#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Workspace API..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates (e.g., letsencrypt-prod)" "letsencrypt-prod" is_non_empty
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty

# Stage-in S3 configuration
ask "STAGEIN_S3_ENDPOINT" "Enter the Stage-In S3 Endpoint URL (e.g., stage-in-s3.$INGRESS_HOST)" "stage-in-s3.$INGRESS_HOST" is_valid_domain
ask "STAGEIN_S3_ACCESS_KEY" "Enter the Stage-In S3 Access Key" "" is_non_empty
ask "STAGEIN_S3_SECRET_KEY" "Enter the Stage-In S3 Secret Key" "" is_non_empty
ask "STAGEIN_S3_REGION" "Enter the Stage-In S3 Region" "eu-west-2" is_non_empty

# Primary S3 configuration
check "Do you have an existing S3 object store?" "Please setup an S3 object store before proceeding."
ask "S3_ENDPOINT" "Enter the S3 Endpoint URL (e.g., minio.$INGRESS_HOST)" "minio.$INGRESS_HOST" is_valid_domain
ask "S3_ACCESS_KEY" "Enter the S3 Access Key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the S3 Secret Key" "" is_non_empty
ask "S3_REGION" "Enter the S3 Region" "RegionOne" is_non_empty

# Gatekeeper
ask "ADES_CLIENT_SECRET" "Enter the Keycloak client secret for ADES" "" is_non_empty
export ENCRYPTION_KEY=$(generate_aes_key 32)

envsubst < "$TEMPLATE_PATH" > "$OUTPUT_PATH"
envsubst < "$GATEKEEPER_TEMPLATE_PATH" > "$GATEKEEPER_OUTPUT_PATH"
