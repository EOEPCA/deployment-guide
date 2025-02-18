#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Workspace Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
configure_cert

# S3 configuration
ask "S3_ENDPOINT" "Enter the S3 endpoint URL" "$HTTP_SCHEME://minio.${INGRESS_HOST}" is_non_empty
ask "S3_REGION" "Enter the S3 region" "us-east-1" is_non_empty
ask "S3_ACCESS_KEY" "Enter the MinIO access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the MinIO secret key" "" is_non_empty
ask "HARBOR_ADMIN_PASSWORD" "Enter the Harbor admin password" "" is_non_empty

if [ -z "$WORKSPACE_UI_PASSWORD" ]; then
    add_to_state_file "WORKSPACE_UI_PASSWORD" $(generate_aes_key 32)
fi

# OIDC
ask "OIDC_WORKSPACE_ENABLED" "Do you want to enable authentication using the IAM Building Block?" "true" is_boolean
if [ "$OIDC_WORKSPACE_ENABLED" == "true" ]; then

    ask "WORKSPACE_CLIENT_ID" "Enter the Client ID for the Workspace" "workspace" is_non_empty

    if [ -z "$WORKSPACE_CLIENT_SECRET" ]; then
        WORKSPACE_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "WORKSPACE_CLIENT_SECRET" "$WORKSPACE_CLIENT_SECRET"
    fi
    echo ""
    echo "❗  Generated client secret for the Workspace."
    echo "   Please store this securely: $WORKSPACE_CLIENT_SECRET"
    echo ""

fi

# Generate configuration files
envsubst <"workspace-api/values-template.yaml" >"workspace-api/generated-values.yaml"
envsubst <"workspace-api/ingress-template.yaml" >"workspace-api/generated-ingress.yaml"
envsubst <"workspace-ui/values-template.yaml" >"workspace-ui/generated-values.yaml"
envsubst <"workspace-admin/values-template.yaml" >"workspace-admin/generated-values.yaml"
envsubst <"workspace-pipelines/kustomization-template.yaml" >"workspace-pipelines/kustomization.yaml"

echo "Please proceed to apply the necessary Kubernetes secrets before deploying."

echo ""
echo "🔐 IMPORTANT: The following secrets have been generated or used for your deployment:"
echo "Workspace UI Password: $WORKSPACE_UI_PASSWORD"
echo ""

if [ "$USE_CERT_MANAGER" == "no" ]; then
    echo ""
    echo "📄 Since you're not using cert-manager, please create the following TLS secrets manually before deploying:"
    echo "- workspace-admin-tls"
    echo "- workspace-api-tls"
    echo "- workspace-ui-tls"
fi
