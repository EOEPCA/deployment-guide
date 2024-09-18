#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Identity Service..."

# Collect user inputs
ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates (e.g., letsencrypt-prod)" "letsencrypt-prod" is_non_empty
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "DB_STORAGE_CLASS" "Specify the storage class for the Identity Service database (e.g., managed-nfs-storage-retain)" "managed-nfs-storage-retain" is_non_empty

ask "IS_NAMESPACE_OVERRIDE" "Enter the Kubernetes namespace for the Identity Service" "default" is_non_empty
ask "IS_VOLUME_CLAIM_NAME" "Enter the Persistent Volume Claim name for the Identity Service database" "identity-vol" is_non_empty
ask "IS_CREATE_VOLUME_CLAIM" "Do you want to create a new Persistent Volume Claim? (true/false)" "true" is_boolean

# Generate passwords
export IS_POSTGRES_PASSWORD=$(generate_password)
export IS_KEYCLOAK_ADMIN_PASSWORD=$(generate_password)
export IS_KEYCLOAK_DB_PASSWORD=$(generate_password)
export IS_API_ADMIN_PASSWORD=$(generate_password)
export IS_API_GATEKEEPER_CLIENT_SECRET=$(generate_password)
export IS_API_GATEKEEPER_ENCRYPTION_KEY=$(generate_password)

envsubst < "$TEMPLATE_PATH" > "$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"

# Notify the user to store the generated passwords
echo ""
echo "🔐 IMPORTANT: The following passwords have been generated for your deployment:"
echo "PostgreSQL Password: $IS_POSTGRES_PASSWORD"
echo "Keycloak Admin Password: $IS_KEYCLOAK_ADMIN_PASSWORD"
echo "Keycloak DB Password: $IS_KEYCLOAK_DB_PASSWORD"
echo "Identity API Admin Password: $IS_API_ADMIN_PASSWORD"
echo "Identity API Gatekeeper Client Secret: $IS_API_GATEKEEPER_CLIENT_SECRET"
echo "Identity API Gatekeeper Encryption Key: $IS_API_GATEKEEPER_ENCRYPTION_KEY"
echo "Please ensure these are stored securely!"