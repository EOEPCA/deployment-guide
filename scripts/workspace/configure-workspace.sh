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

# OIDC
ask "OIDC_WORKSPACE_ENABLED" "Do you want to enable authentication using the IAM Building Block?" "true" is_boolean
if [ "$OIDC_WORKSPACE_ENABLED" == "true" ]; then
    # WORKSPACE API CLIENT
    ask "WORKSPACE_API_CLIENT_ID" "Enter the Client ID for the Workspace API" "workspace-api" is_non_empty
    if [ -z "$WORKSPACE_API_CLIENT_SECRET" ]; then
        WORKSPACE_API_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "WORKSPACE_API_CLIENT_SECRET" "$WORKSPACE_API_CLIENT_SECRET"
    fi
    echo ""
    echo "❗  Generated client secret for the Workspace."
    echo "   Please store this securely: $WORKSPACE_API_CLIENT_SECRET"
    echo ""

    # WORKSPACE PIPELINE CLIENT
    ask "WORKSPACE_PIPELINE_CLIENT_ID" "Enter the Client ID for the Workspace Pipeline" "workspace-pipeline" is_non_empty
    if [ -z "$WORKSPACE_PIPELINE_CLIENT_SECRET" ]; then
        WORKSPACE_PIPELINE_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "WORKSPACE_PIPELINE_CLIENT_SECRET" "$WORKSPACE_PIPELINE_CLIENT_SECRET"
    fi
    echo ""
    echo "❗  Generated client secret for the Workspace Pipeline."
    echo "   Please store this securely: $WORKSPACE_PIPELINE_CLIENT_SECRET"
    echo ""
fi

ask "KEYCLOAK_TEST_USER" "Enter the username for the example user" "eoepcauser"
ask "KEYCLOAK_TEST_ADMIN" "Enter the username for the example ADMIN user" "eoepcaadmin"
ask "KEYCLOAK_TEST_PASSWORD" "Enter the password for the example users" "eoepcapassword"

# Deduce the service CIDR from the cluster
export SERVICE_CIDR=$(kubectl get svc kubernetes -n default -o json | jq -r '.spec.clusterIP' | awk -F. '{printf "%d.%d.0.0/12", $1, $2}')

# Generate configuration files
gomplate -f "workspace-api/values-template.yaml" -o "workspace-api/generated-values.yaml"
gomplate -f "workspace-api/ingress-template.yaml" -o "workspace-api/generated-ingress.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "workspace-admin/values-template.yaml" -o "workspace-admin/generated-values.yaml"
gomplate -f "workspace-admin/ingress-template.yaml" -o "workspace-admin/generated-ingress.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "workspace-dependencies/educates-values-template.yaml" -o "workspace-dependencies/educates-values.yaml"
gomplate -f "workspace-pipeline/values-template.yaml" -o "workspace-pipeline/generated-values.yaml"

echo ""
echo "✅ Configuration complete!"
echo "Please proceed to apply the necessary Kubernetes secrets before deploying."