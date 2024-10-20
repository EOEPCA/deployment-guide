#!/bin/bash

echo "Configuring the App Hub..."
source ../common/utils.sh

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "default" is_non_empty
configure_cert

# OAuth2 configuration
ask "APPHUB_CLIENT_SECRET" "Enter the Keycloak client secret for App Hub" "" is_non_empty
export APPHUB_JUPYTERHUB_CRYPT_KEY=$(openssl rand -base64 32)
add_to_state_file "APPHUB_JUPYTERHUB_CRYPT_KEY" $APPHUB_JUPYTERHUB_CRYPT_KEY

envsubst <"$TEMPLATE_PATH" >"$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"

if [ "$USE_CERT_MANAGER" == "no" ]; then
    echo ""
    echo "📄 Since you're not using cert-manager, please create the following TLS secrets manually before deploying:"
    echo "- app-hub-tls (for App Hub)"
fi