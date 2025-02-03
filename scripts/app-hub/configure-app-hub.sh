#!/bin/bash

echo "Configuring the App Hub..."
source ../common/utils.sh

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert
ask "NODE_SELECTOR_KEY" "Specify the selector to determine which nodes will run the Application Hub pods" "node-role.kubernetes.io/worker" is_non_empty
ask "NODE_SELECTOR_VALUE" "Specify the value of the node selector" "true" is_non_empty
ask "KEYCLOAK_HOST" "Enter the Keycloak full host domain excluding https (e.g., auth.example.com)" "auth.example.com" is_valid_domain
ask "APPHUB_ALLOWED_USER" "Enter the username of the user allowed to access the App Hub" "eoepcauser" is_non_empty

# OAuth2 configuration
ask "APPHUB_CLIENT_ID" "Enter the Client ID for the OAPIP" "application-hub" is_non_empty

if [ -z "$APPHUB_CLIENT_SECRET" ]; then
    APPHUB_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "APPHUB_CLIENT_SECRET" "$APPHUB_CLIENT_SECRET"

    echo ""
    echo "❗  Generated client secret for the App Hub."
    echo "   Please store this securely: $APPHUB_CLIENT_SECRET"
    echo ""
fi

if [ -z "$APPHUB_JUPYTERHUB_CRYPT_KEY" ]; then
    export APPHUB_JUPYTERHUB_CRYPT_KEY=$(openssl rand -base64 32)
    add_to_state_file "APPHUB_JUPYTERHUB_CRYPT_KEY" $APPHUB_JUPYTERHUB_CRYPT_KEY
fi

envsubst <"$TEMPLATE_PATH" >"$OUTPUT_PATH"
envsubst <"$INGRESS_TEMPLATE_PATH" >"$INGRESS_OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"
