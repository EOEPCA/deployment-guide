#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Application Quality Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty
configure_cert

# Generate secret key for the application (if not already set)
if [ -z "$APPLICATION_QUALITY_SECRET_KEY" ]; then
    add_to_state_file "APPLICATION_QUALITY_SECRET_KEY" "$(generate_aes_key 32)"
fi

# Generate configuration file
envsubst <"$TEMPLATE_PATH" >"$OUTPUT_PATH"

if [ "$USE_CERT_MANAGER" == "no" ]; then
    echo ""
    echo "📄 Since you're not using cert-manager, please create the following TLS secrets manually before deploying:"
    echo "- application-quality-tls"
fi