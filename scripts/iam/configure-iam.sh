#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the IAM..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
ask "REALM" "Enter what you'd like for the Keycloak realm name" "eoepca" is_non_empty
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

# OIDC client secrets
ask "OPA_CLIENT_ID" "Enter the OPA client ID" "opa" is_non_empty
if [ -z "$OPA_CLIENT_SECRET" ]; then
    OPA_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "OPA_CLIENT_SECRET" "$OPA_CLIENT_SECRET"
fi
ask "IDENTITY_API_CLIENT_ID" "Enter the Identity API client ID" "identity-api" is_non_empty
if [ -z "$IDENTITY_API_CLIENT_SECRET" ]; then
    IDENTITY_API_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "IDENTITY_API_CLIENT_SECRET" "$IDENTITY_API_CLIENT_SECRET"
fi

echo ""
echo "❗  Generated passwords:"
echo "KEYCLOAK_ADMIN_PASSWORD: $KEYCLOAK_ADMIN_PASSWORD"
echo "KEYCLOAK_POSTGRES_PASSWORD: $KEYCLOAK_POSTGRES_PASSWORD"
echo
echo "OPA_CLIENT_ID: $OPA_CLIENT_ID"
echo "OPA_CLIENT_SECRET: $OPA_CLIENT_SECRET"
echo
echo "IDENTITY_API_CLIENT_ID: $IDENTITY_API_CLIENT_ID"
echo "IDENTITY_API_CLIENT_SECRET: $IDENTITY_API_CLIENT_SECRET"
echo ""


add_to_state_file "KEYCLOAK_HOST" "auth.$INGRESS_HOST"
add_to_state_file "OIDC_ISSUER_URL" "${HTTP_SCHEME}://auth.$INGRESS_HOST/realms/$REALM"

# Generate configuration files
echo "Generating configuration files..."

gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
if [ "$INGRESS_CLASS" == "apisix" ]; then
    gomplate -f "apisix-tls-template.yaml" -o "apisix-tls.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

echo "✅ Configuration files generated."
