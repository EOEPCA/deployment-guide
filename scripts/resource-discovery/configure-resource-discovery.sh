#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Discovery..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

envsubst <"$TEMPLATE_PATH" >"$OUTPUT_PATH"
envsubst <"$INGRESS_TEMPLATE_PATH" >"$INGRESS_OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"
