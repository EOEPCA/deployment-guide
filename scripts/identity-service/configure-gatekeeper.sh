#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Identity Gatekeeper..."

ask "CLUSTER_ISSUER" "Specify the cert-manager Cluster Issuer for TLS certificates (e.g., letsencrypt-prod)" "letsencrypt-prod" is_non_empty
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "IS_API_CLIENT_SECRET" "Enter the Keycloak client secret for the Identity Service (identity-api)" "" is_non_empty

export ENCRYPTION_KEY=$(generate_aes_key 32)

envsubst < "$GATEKEEPER_TEMPLATE_PATH" > "$GATEKEEPER_OUTPUT_PATH"
