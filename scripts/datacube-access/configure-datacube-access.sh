#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring Datacube Access..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates" "letsencrypt-http01-apisix" is_non_empty
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
ask "STAC_CATALOG_ENDPOINT" "Enter a STAC catalog endpoint" "https://eoapi.${INGRESS_HOST}/stac" is_non_empty


gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ Configuration file generated: $OUTPUT_PATH"
echo "✅ Ingress configuration generated: $INGRESS_OUTPUT_PATH"
