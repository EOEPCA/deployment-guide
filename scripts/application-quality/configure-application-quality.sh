#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Application Quality Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
configure_cert
ask "INTERNAL_CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for internal TLS certificates" "eoepca-ca-clusterissuer" is_non_empty


# OIDC configuration - now optional
ask_yes_no "APP_QUALITY_ENABLE_OIDC" "Enable OIDC authentication?" "no"

if [ "$APP_QUALITY_ENABLE_OIDC" = "yes" ]; then
    export OIDC_APPLICATION_QUALITY_ENABLED="true"
    
    if [ -z "$OIDC_ISSUER_URL" ]; then
        ask "OIDC_ISSUER_URL" "Enter the OIDC issuer URL" "https://keycloak.${INGRESS_HOST}/auth/realms/${REALM}" is_non_empty
    fi

    ask "APP_QUALITY_CLIENT_ID" "Enter the OIDC client ID for the Application Quality Building Block" "application-quality" is_non_empty

    if [ -z "$APP_QUALITY_CLIENT_SECRET" ]; then
        APP_QUALITY_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "APP_QUALITY_CLIENT_SECRET" "$APP_QUALITY_CLIENT_SECRET"
    fi

    echo ""
    echo "❗  Generated client secret for the Application Quality."
    echo "   Application Quality Client Secret: $APP_QUALITY_CLIENT_SECRET"
    echo ""

    add_to_state_file "OSD_BASE_REDIRECT" "${HTTP_SCHEME}://application-quality.${INGRESS_HOST}/dashboards"
    add_to_state_file "OSD_CONNECT_URL" "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}/.well-known/openid-configuration"
else
    export OIDC_APPLICATION_QUALITY_ENABLED="false"
    export APP_QUALITY_CLIENT_ID=""
    export APP_QUALITY_CLIENT_SECRET=""
    echo ""
    echo "ℹ️  OIDC authentication disabled. The API will allow unauthenticated access."
    echo ""
fi

# Generate configuration file
gomplate  -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

