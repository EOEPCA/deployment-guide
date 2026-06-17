#!/bin/bash

echo "Configuring the Application Hub..."
source ../common/utils.sh

# Collect user inputs
configure_http_scheme
configure_ingress
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
configure_cert
ask "NODE_SELECTOR_KEY" "Specify the selector to determine which nodes will run the Application Hub pods" "kubernetes.io/os" is_non_empty
ask "NODE_SELECTOR_VALUE" "Specify the value of the node selector" "linux" is_non_empty

# Application Hub 2.1 requires OIDC/JupyterHub authentication.
if [ "${APPHUB_ENABLE_IAM:-true}" != "true" ]; then
    echo "ERROR: Application Hub 2.1 requires IAM/OIDC integration."
    echo "Set APPHUB_ENABLE_IAM=true and configure a Keycloak/OIDC client before deploying."
    exit 1
fi
add_to_state_file "APPHUB_ENABLE_IAM" "true"

if [ "${INGRESS_CLASS}" != "apisix" ] && [ "${INGRESS_CLASS}" != "nginx" ]; then
    echo "ERROR: Unsupported INGRESS_CLASS '${INGRESS_CLASS}'. Use 'apisix' or 'nginx'."
    exit 1
fi

ask "APPHUB_PUBLIC_HOST" "Enter the public Application Hub host" "app-hub.${INGRESS_HOST}" is_valid_domain

# OAuth2 configuration.
ask "APPHUB_CLIENT_ID" "Enter the Client ID for the OAuth provider" "application-hub" is_non_empty

if [ -z "${APPHUB_CLIENT_SECRET:-}" ]; then
    APPHUB_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "APPHUB_CLIENT_SECRET" "$APPHUB_CLIENT_SECRET"
fi

if [ -z "${APPHUB_JUPYTERHUB_CRYPT_KEY:-}" ]; then
    export APPHUB_JUPYTERHUB_CRYPT_KEY=$(generate_aes_key 32)
    add_to_state_file "APPHUB_JUPYTERHUB_CRYPT_KEY" "$APPHUB_JUPYTERHUB_CRYPT_KEY"
fi

if [ -z "${KEYCLOAK_HOST:-}" ]; then
    ask "KEYCLOAK_HOST" "Enter the Keycloak full host domain excluding https (e.g. auth.example.com)" "auth.${INGRESS_HOST}" is_valid_domain
fi

if [ -z "${REALM:-}" ]; then
    ask "REALM" "Enter the Keycloak realm" "eoepca" is_non_empty
fi

add_to_state_file "OIDC_ISSUER_URL" "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}"

echo ""
echo "❗  Generated client secret for the App Hub."
echo "   Please store this securely: $APPHUB_CLIENT_SECRET"
echo ""

gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"
gomplate -f "$INGRESS_TEMPLATE_PATH" -o "$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "iam-template.yaml" -o "generated-iam.yaml"

echo "✅ Configuration file generated: $OUTPUT_PATH"
echo "✅ Configuration file generated: $INGRESS_OUTPUT_PATH"
echo "✅ Configuration file generated: generated-iam.yaml"
