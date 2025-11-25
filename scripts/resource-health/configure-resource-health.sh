#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Health Building Block..."

# Collect user inputs
ask "INTERNAL_CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for internal TLS certificates" "eoepca-ca-clusterissuer" is_non_empty
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
configure_cert

# Ask about OIDC authentication
ask_yes_no "RESOURCE_HEALTH_ENABLE_OIDC" "Do you want to enable OIDC authentication for Resource Health?" "yes"

if [ "$RESOURCE_HEALTH_ENABLE_OIDC" == "yes" ]; then
    ask "RESOURCE_HEALTH_CLIENT_ID" "Enter the Resource Health Keycloak Client ID" "resource-health" is_non_empty

    if [ -z "$RESOURCE_HEALTH_CLIENT_SECRET" ]; then
        RESOURCE_HEALTH_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "RESOURCE_HEALTH_CLIENT_SECRET" "$RESOURCE_HEALTH_CLIENT_SECRET"
    fi
    echo ""
    echo "❗  Generated client secret for Resource Health."
    echo "   Please store this securely: $RESOURCE_HEALTH_CLIENT_SECRET"
    echo ""

    if [ -z "$KEYCLOAK_HOST" ]; then
        ask "KEYCLOAK_HOST" "Enter the Keycloak full host domain excluding https (e.g., auth.example.com)" "auth.${INGRESS_HOST}" is_valid_domain
    fi

    if [ -z "$REALM" ]; then
        ask "REALM" "Enter the Keycloak realm" "eoepca" is_non_empty
    fi

    if [ -z "$KEYCLOAK_TEST_USER" ]; then
        ask "KEYCLOAK_TEST_USER" "Enter your Keycloak test user username" "eoepcauser" is_non_empty
    fi

    if [ -z "$KEYCLOAK_TEST_PASSWORD" ]; then
        ask "KEYCLOAK_TEST_PASSWORD" "Enter your Keycloak test user password" "" is_non_empty
    fi
fi

# APISIX-specific templating
if [ "$INGRESS_CLASS" == "apisix" ]; then
    gomplate -f "apisix/apisix-ingress-template.yaml" -o "$INGRESS_OUTPUT_PATH"
    gomplate -f "apisix/apisix-route-browser-auth-plugin-template.yaml" -o "apisix/plugin-browser-auth.yaml"
    gomplate -f "apisix/apisix-route-plugin-template.yaml" -o "apisix/plugin-api-auth.yaml"

elif [ "$INGRESS_CLASS" == "nginx" ]; then
    gomplate -f "nginx-ingress-template.yaml" -o "$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

# Generate standard configuration files
gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"

echo "You can now proceed to deploy the Resource Health secrets."