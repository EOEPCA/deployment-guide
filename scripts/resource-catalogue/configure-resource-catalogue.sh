#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Catalogue..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty

# ask "RESOURCE_CATALOGUE_INGRESS_ENABLED" "Enable ingress? (true/false)" "true" is_boolean
ask "RESOURCE_CATALOGUE_DB_ENABLED" "Enable local database for the Resource Catalogue? (true/false)" "true" is_boolean
ask "PYCSW_URL" "Set the PyCSW server URL (typically the ingress host)" "$INGRESS_HOST" is_valid_domain

export RC_ENCRYPTION_KEY=$(generate_aes_key 32)
ask "RC_CLIENT_SECRET" "Set the Resource Catalogue client secret" "" is_non_empty

envsubst <"$TEMPLATE_PATH" >"$OUTPUT_PATH"
envsubst < "$GATEKEEPER_TEMPLATE_PATH" > "$GATEKEEPER_OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"

# Notify the user to store the generated passwords
echo ""
echo "🔐 IMPORTANT: The following passwords have been generated for your deployment:"
echo "Resource Catalogue Gatekeeper Encryption Key: $RC_ENCRYPTION_KEY"