#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Health Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty
ask "INTERNAL_CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for internal TLS certificates" "eoepca-ca-clusterissuer" is_non_empty

ask "KEYCLOAK_CLIENT_ID" "Enter the Keycloak client ID for Resource Health BB" "" is_non_empty
ask "KEYCLOAK_CLIENT_SECRET" "Enter the Keycloak client secret for Resource Health BB" "" is_non_empty

# Generate passwords and store them in the state file
add_to_state_file "SENSMETRY_USERNAME" "sensmetry"
if [ -z "$SENSMETRY_PASSWORD" ]; then
    add_to_state_file "SENSMETRY_PASSWORD" "$(generate_password)"
fi

# Generate bcrypt hash of the password for OpenSearch internal user
SENSMETRY_PASSWORD_HASH=$(mkpasswd -m bcrypt "$SENSMETRY_PASSWORD")
add_to_state_file "SENSMETRY_PASSWORD_HASH" "$SENSMETRY_PASSWORD_HASH"

# Generate configuration files
envsubst <"resource-health/values-template.yaml" >"resource-health/generated-values.yaml"
envsubst <"opensearch/values-template.yaml" >"opensearch/generated-values.yaml"
envsubst <"opensearch-dashboards/values-template.yaml" >"opensearch-dashboards/generated-values.yaml"
envsubst <"opentelemetry-collector/values-template.yaml" >"opentelemetry-collector/generated-values.yaml"

echo ""
echo "🔐 IMPORTANT: The following secrets have been generated or used for your deployment:"
echo "Sensmetry Username: sensmetry"
echo "Sensmetry Password: $SENSMETRY_PASSWORD"
echo ""
echo "Please proceed to apply the necessary Kubernetes secrets and certificates before deploying."