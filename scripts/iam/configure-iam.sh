#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the IAM..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

# Generate passwords and store them in the state file
if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
    KEYCLOAK_ADMIN_PASSWORD=$(generate_aes_key 16)
    add_to_state_file "KEYCLOAK_ADMIN_PASSWORD" "$KEYCLOAK_ADMIN_PASSWORD"
fi
if [ -z "$KEYCLOAK_POSTGRES_PASSWORD" ]; then
    KEYCLOAK_POSTGRES_PASSWORD=$(generate_aes_key 16)
    add_to_state_file "KEYCLOAK_POSTGRES_PASSWORD" "$KEYCLOAK_POSTGRES_PASSWORD"
fi
add_to_state_file "KEYCLOAK_ADMIN_USER" "admin"
if [ -z "$OPA_CLIENT_SECRET" ]; then
    OPA_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "OPA_CLIENT_SECRET" "$OPA_CLIENT_SECRET"
fi
add_to_state_file "KEYCLOAK_HOST" "auth.$INGRESS_HOST"

# Generate configuration files
echo "Generating configuration files..."

gomplate -f "keycloak/$TEMPLATE_PATH" -o "keycloak/$OUTPUT_PATH"
gomplate -f "opa/$TEMPLATE_PATH" -o "opa/$OUTPUT_PATH"

if [ "$INGRESS_CLASS" == "apisix" ]; then
    gomplate -f "keycloak/apisix-ingress-template.yaml" -o "keycloak/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    gomplate -f "opa/apisix-ingress-template.yaml" -o "opa/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
else
    gomplate -f "keycloak/nginx-ingress-template.yaml" -o "keycloak/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    gomplate -f "opa/nginx-ingress-template.yaml" -o "opa/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi


echo "✅ Configuration files generated."
