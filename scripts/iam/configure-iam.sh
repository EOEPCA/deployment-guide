#!/bin/bash

source ../common/utils.sh
echo "Configuring the IAM..."

if [ "${INGRESS_CLASS}" != "apisix" ]; then
    echo "❌ IAM currently requires INGRESS_CLASS=apisix."
    echo "   The IAM chart generates APISIX routes for Keycloak and OPA; nginx is not supported for this guide path."
    exit 1
fi

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
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

# Crossplane Keycloak provider and OPA route secrets
if [ -z "${IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET:-}" ]; then
    IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET="${IAM_MANAGEMENT_CLIENT_SECRET:-$(generate_aes_key 32)}"
    add_to_state_file "IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET" "$IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET"
fi
ask "OPA_CLIENT_ID" "Enter the OPA client ID" "opa" is_non_empty
if [ -z "$OPA_CLIENT_SECRET" ]; then
    OPA_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "OPA_CLIENT_SECRET" "$OPA_CLIENT_SECRET"
fi
if [ -z "${IAM_OPA_SESSION_SECRET:-}" ]; then
    IAM_OPA_SESSION_SECRET=$(generate_aes_key 32)
    add_to_state_file "IAM_OPA_SESSION_SECRET" "$IAM_OPA_SESSION_SECRET"
fi

ask "KEYCLOAK_TEST_USER" "Enter the username for the example user" "eoepcauser"
ask "KEYCLOAK_TEST_ADMIN" "Enter the username for the example ADMIN user" "eoepcaadmin"
ask "KEYCLOAK_TEST_PASSWORD" "Enter the password for the example users" "eoepcapassword"

echo ""
echo "❗  Generated passwords:"
echo "KEYCLOAK_ADMIN_PASSWORD: $KEYCLOAK_ADMIN_PASSWORD"
echo "KEYCLOAK_POSTGRES_PASSWORD: $KEYCLOAK_POSTGRES_PASSWORD"
echo
echo "IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET: $IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET"
echo
echo "OPA_CLIENT_ID: $OPA_CLIENT_ID"
echo "OPA_CLIENT_SECRET: $OPA_CLIENT_SECRET"
echo "IAM_OPA_SESSION_SECRET: $IAM_OPA_SESSION_SECRET"
echo ""

KEYCLOAK_HOST=${KEYCLOAK_HOST:-"auth.$INGRESS_HOST"}

add_to_state_file "KEYCLOAK_HOST" "$KEYCLOAK_HOST"
add_to_state_file "OIDC_ISSUER_URL" "${HTTP_SCHEME}://$KEYCLOAK_HOST/realms/$REALM"

echo "Generating configuration files..."

gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "apisix-tls-template.yaml" -o "apisix-tls.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "eoepca-user-template.yaml" -o "generated-eoepca-user.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ Configuration files generated."
