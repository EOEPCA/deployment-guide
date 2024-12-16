#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the IAM..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

# Generate passwords and store them in the state file
if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
    KEYCLOAK_ADMIN_PASSWORD=$(generate_password)
    add_to_state_file "KEYCLOAK_ADMIN_PASSWORD" "$KEYCLOAK_ADMIN_PASSWORD"
fi
if [ -z "$KEYCLOAK_POSTGRES_PASSWORD" ]; then
    KEYCLOAK_POSTGRES_PASSWORD=$(generate_password)
    add_to_state_file "KEYCLOAK_POSTGRES_PASSWORD" "$KEYCLOAK_POSTGRES_PASSWORD"
fi
add_to_state_file "KEYCLOAK_ADMIN_USER" "admin"
if [ -z "$OPA_CLIENT_SECRET" ]; then
    OPA_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "OPA_CLIENT_SECRET" "$OPA_CLIENT_SECRET"
fi

# Generate configuration files
echo "Generating configuration files..."

envsubst < "keycloak/values-template.yaml" > "keycloak/generated-values.yaml"
envsubst < "keycloak/ingress-template.yaml" > "keycloak/generated-ingress.yaml"
envsubst < "opa/ingress-template.yaml" > "opa/generated-ingress.yaml"

echo "✅ Configuration files generated."
