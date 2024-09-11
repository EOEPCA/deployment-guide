#!/bin/bash

# Load utility functions
source ../common/utils.sh

# Template paths
template_path="./values-template.yaml"
intermediate_output_path="./intermediate-values.yaml"
final_output_path="./generated-values-2.yaml"

# Collect user inputs
ask IS_NAMESPACE_OVERRIDE "Enter the namespace for the Identity Service:" "default"
ask DB_STORAGE_CLASS "Enter the storage class for the Identity Service database:" "managed-nfs-storage-retain"
ask IS_VOLUME_CLAIM_NAME "Enter the volume claim name for the Identity Service:" "identity-vol"
ask IS_CREATE_VOLUME_CLAIM "Do you want to create a volume claim? [true/false]:" "true"
ask IS_CERT_MANAGER_CLUSTER_ISSUER "Enter the cert-manager cluster issuer name:" "letsencrypt-prod"
ask IS_INGRESS_HOST "Enter the base ingress host for the Identity Service (e.g., mydomain.com):" "identity.example.com"

# Generate passwords
IS_POSTGRES_PASSWORD=$(generate_password)
IS_KEYCLOAK_ADMIN_PASSWORD=$(generate_password)
IS_KEYCLOAK_DB_PASSWORD=$(generate_password)
IS_API_ADMIN_PASSWORD=$(generate_password)
IS_API_GATEKEEPER_CLIENT_SECRET=$(generate_password)
IS_API_GATEKEEPER_ENCRYPTION_KEY=$(generate_password)

# Apply replacements
cp "$template_path" "$intermediate_output_path"

replace_placeholder "$intermediate_output_path" "$final_output_path" "IS_NAMESPACE_OVERRIDE" "$IS_NAMESPACE_OVERRIDE"
replace_placeholder "$final_output_path" "$final_output_path" "DB_STORAGE_CLASS" "$DB_STORAGE_CLASS"
replace_placeholder "$final_output_path" "$final_output_path" "IS_POSTGRES_PASSWORD" "$IS_POSTGRES_PASSWORD"
replace_placeholder "$final_output_path" "$final_output_path" "IS_VOLUME_CLAIM_NAME" "$IS_VOLUME_CLAIM_NAME"
replace_placeholder "$final_output_path" "$final_output_path" "IS_CREATE_VOLUME_CLAIM" "$IS_CREATE_VOLUME_CLAIM"
replace_placeholder "$final_output_path" "$final_output_path" "IS_KEYCLOAK_ADMIN_PASSWORD" "$IS_KEYCLOAK_ADMIN_PASSWORD"
replace_placeholder "$final_output_path" "$final_output_path" "IS_KEYCLOAK_DB_PASSWORD" "$IS_KEYCLOAK_DB_PASSWORD"
replace_placeholder "$final_output_path" "$final_output_path" "IS_CERT_MANAGER_CLUSTER_ISSUER" "$IS_CERT_MANAGER_CLUSTER_ISSUER"
replace_placeholder "$final_output_path" "$final_output_path" "IS_INGRESS_HOST" "$IS_INGRESS_HOST"
replace_placeholder "$final_output_path" "$final_output_path" "IS_API_ADMIN_PASSWORD" "$IS_API_ADMIN_PASSWORD"
replace_placeholder "$final_output_path" "$final_output_path" "IS_API_GATEKEEPER_CLIENT_SECRET" "$IS_API_GATEKEEPER_CLIENT_SECRET"
replace_placeholder "$final_output_path" "$final_output_path" "IS_API_GATEKEEPER_ENCRYPTION_KEY" "$IS_API_GATEKEEPER_ENCRYPTION_KEY"

echo "Configuration file generated: $final_output_path"

# Notify the user to securely store the generated passwords
echo ""
echo "🔐 IMPORTANT: The following passwords have been generated for your deployment:"
echo "PostgreSQL Password: $IS_POSTGRES_PASSWORD"
echo "Keycloak Admin Password: $IS_KEYCLOAK_ADMIN_PASSWORD"
echo "Keycloak DB Password: $IS_KEYCLOAK_DB_PASSWORD"
echo "API Admin Password: $IS_API_ADMIN_PASSWORD"
echo "API Gatekeeper Client Secret: $IS_API_GATEKEEPER_CLIENT_SECRET"
echo "API Gatekeeper Encryption Key: $IS_API_GATEKEEPER_ENCRYPTION_KEY"
echo "Please ensure these are stored securely!"
