#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Identity Service..."

# Collect user inputs
ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates (e.g., letsencrypt-prod)" "letsencrypt-prod" is_non_empty
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "DB_STORAGE_CLASS" "Specify the storage class for the Identity Service database (e.g., managed-nfs-storage-retain)" "managed-nfs-storage-retain" is_non_empty

# Generate other variables
add_to_state_file "IS_POSTGRES_PASSWORD" $(generate_password)
add_to_state_file "IS_KEYCLOAK_ADMIN_USERNAME" "admin"
add_to_state_file "IS_KEYCLOAK_ADMIN_PASSWORD" $(generate_password)
add_to_state_file "KEYCLOAK_URL" "identity.keycloak.$INGRESS_HOST"
add_to_state_file "IDENTITY_API_URL" "identity.api.$INGRESS_HOST"

envsubst < "$TEMPLATE_PATH" > "$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"

# Notify the user to store the generated passwords
echo ""
echo "🔐 IMPORTANT: The following passwords have been generated for your deployment:"
echo "PostgreSQL Password: $IS_POSTGRES_PASSWORD"
echo "Keycloak Admin Username: $IS_KEYCLOAK_ADMIN_USERNAME"
echo "Keycloak Admin Password: $IS_KEYCLOAK_ADMIN_PASSWORD"
echo "Please ensure these are stored securely!"

# Manually apply the pvc
kubectl apply -f ./manual-pvc.yaml
