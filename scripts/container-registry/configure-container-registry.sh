#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Container Registry..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty

export HARBOR_ADMIN_PASSWORD=$(generate_password)
export HARBOR_URL="https://harbor.$INGRESS_HOST"

add_to_state_file "HARBOR_ADMIN_PASSWORD" $HARBOR_ADMIN_PASSWORD
add_to_state_file "HARBOR_URL" $HARBOR_URL

envsubst <"$TEMPLATE_PATH" >"$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"

# Notify the user to store the generated passwords
echo ""
echo "🔐 IMPORTANT: The following passwords have been generated for your deployment:"
echo "Harbor admin password: $HARBOR_ADMIN_PASSWORD"