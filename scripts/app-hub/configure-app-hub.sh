#!/bin/bash

echo "Configuring the App Hub..."
source ../common/utils.sh

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty
ask "APPHUB_CLIENT_SECRET" "Enter the Keycloak client secret for App Hub" "" is_non_empty

export APPHUB_JUPYTERHUB_CRYPT_KEY=$(openssl rand -base64 32)

envsubst <"$TEMPLATE_PATH" >"$OUTPUT_PATH"

echo "✅ Configuration file generated: $OUTPUT_PATH"

# Notify the user to store the generated passwords
echo ""
echo "🔐 IMPORTANT: The following passwords have been generated for your deployment:"
echo "JupyterHub crypt key: $APPHUB_JUPYTERHUB_CRYPT_KEY"
