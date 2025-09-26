#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Discovery..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
configure_cert

gomplate  -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "$INGRESS_TEMPLATE_PATH" -o "$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"


echo "✅ Configuration file generated: $OUTPUT_PATH"
echo "✅ Configuration file generated: $INGRESS_OUTPUT_PATH"
