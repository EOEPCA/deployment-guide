#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring Datacube Access..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STAC_CATALOG_ENDPOINT" "Enter a STAC catalog endpoint" "https://eoapi.${INGRESS_HOST}/stac/" is_non_empty
configure_cert

gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ Configuration file generated: $OUTPUT_PATH"
