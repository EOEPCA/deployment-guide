#!/bin/bash

source ../common/utils.sh
echo "Configuring Datacube Access..."

ask "STAC_CATALOG_ENDPOINT" "Enter a STAC catalog endpoint" "https://eoapi.${INGRESS_HOST}/stac/" is_non_empty

gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ Configuration file generated: $OUTPUT_PATH"
