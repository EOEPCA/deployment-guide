#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Application Quality Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert
ask "INTERNAL_CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for internal TLS certificates" "eoepca-ca-clusterissuer" is_non_empty

# Generate secret key for the application (if not already set)
if [ -z "$APPLICATION_QUALITY_SECRET_KEY" ]; then
    add_to_state_file "APPLICATION_QUALITY_SECRET_KEY" "$(generate_aes_key 32)"
fi

# OIDC configuration
ask "OIDC_APPLICATION_QUALITY_ENABLED" "Do you want to enable authentication using the IAM Building Block?" "true" is_boolean

if [ "$OIDC_APPLICATION_QUALITY_ENABLED" == "true" ]; then
    echo ""
    echo "Please ensure that you have configured the Identity and Access Management Building Block guide."
    echo ""

    # OIDC Configuration
    ask "OIDC_RP_CLIENT_ID" "Enter the OIDC client ID for the Application Quality Building Block" "application-quality-bb" is_non_empty
    ask "OIDC_RP_CLIENT_SECRET" "Enter the OIDC client secret for the Application Quality Building Block" "changeme" is_non_empty

    # OSD Configuration
    ask "OSD_CLIENT_ID" "Enter the OpenSearch Dashboards client ID" "os-dash-client" is_non_empty
    ask "OSD_CLIENT_SECRET" "Enter the OpenSearch Dashboards client secret" "changeme" is_non_empty

    add_to_state_file "OSD_BASE_REDIRECT" "https://application-quality.${INGRESS_HOST}/dashboards"
    add_to_state_file "OSD_CONNECT_URL" "https://iam-auth.${INGRESS_HOST}/realms/eoepca/.well-known/openid-configuration"
else
    echo "OIDC authentication is currently a requirement of this Building Block. The application will still deploy, but it will not be fully operational."
    exit 1
fi

# Generate configuration file
envsubst <"$TEMPLATE_PATH" >"$OUTPUT_PATH"
