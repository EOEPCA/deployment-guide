#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Resource Registration..."

# Collect user inputs
ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates (e.g., letsencrypt-prod)" "letsencrypt-prod" is_non_empty
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain

envsubst < "$TEMPLATE_PATH" > "$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"