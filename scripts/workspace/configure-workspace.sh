#!/bin/bash

source ../common/utils.sh
echo "Configuring the Workspace Building Block..."

# Relies on ApisixRoute/ApisixPluginConfig, so only APISIX is currently supported.
if [ "${INGRESS_CLASS}" != "apisix" ]; then
    echo "❌ The Workspace Building Block currently requires INGRESS_CLASS=apisix."
    exit 1
fi

ask "S3_ENDPOINT" "Enter the S3 endpoint URL" "$HTTP_SCHEME://minio.${INGRESS_HOST}" is_non_empty
ask "S3_REGION" "Enter the S3 region" "us-east-1" is_non_empty
ask "S3_ACCESS_KEY" "Enter the MinIO access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the MinIO secret key" "" is_non_empty

# Required regardless of OIDC_WORKSPACE_ENABLED - self-serves Keycloak resources per workspace.
ask "WORKSPACE_PIPELINE_CLIENT_ID" "Enter the Client ID for the Workspace Pipeline" "workspace-pipeline" is_non_empty
if [ -z "$WORKSPACE_PIPELINE_CLIENT_SECRET" ]; then
    WORKSPACE_PIPELINE_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "WORKSPACE_PIPELINE_CLIENT_SECRET" "$WORKSPACE_PIPELINE_CLIENT_SECRET"
fi
echo ""
echo "❗  Generated client secret for the Workspace Pipeline."
echo "   Please store this securely: $WORKSPACE_PIPELINE_CLIENT_SECRET"
echo ""

ask "WORKSPACE_API_CLIENT_ID" "Enter the Client ID for the Workspace API" "workspace-api" is_non_empty
if [ -z "$WORKSPACE_API_SESSION_SECRET" ]; then
    WORKSPACE_API_SESSION_SECRET=$(generate_aes_key 32)
    add_to_state_file "WORKSPACE_API_SESSION_SECRET" "$WORKSPACE_API_SESSION_SECRET"
fi

# Only controls ingress-level redirect-to-login and Datalab session SSO - the
# Workspace API itself always requires a Bearer token regardless of this setting.
ask "OIDC_WORKSPACE_ENABLED" "Do you want ingress-level login redirect and Datalab session SSO via Keycloak?" "true" is_boolean

ask "KEYCLOAK_TEST_USER" "Enter the username for the example user" "eoepcauser"
ask "KEYCLOAK_TEST_ADMIN" "Enter the username for the example ADMIN user" "eoepcaadmin"
ask "KEYCLOAK_TEST_PASSWORD" "Enter the password for the example users" "eoepcapassword"

# Used to scope the NetworkPolicy applied to each provisioned Datalab/session pod.
export SERVICE_CIDR=$(kubectl get svc kubernetes -n default -o json | jq -r '.spec.clusterIP' | awk -F. '{printf "%d.%d.0.0/12", $1, $2}')
export POD_CIDRS=$(kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}' | tr ' ' ',')

gomplate -f "workspace-api/values-template.yaml" -o "workspace-api/generated-values.yaml"
gomplate -f "workspace-api/ingress-template.yaml" -o "workspace-api/generated-ingress.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "workspace-dependencies/educates-values-template.yaml" -o "workspace-dependencies/educates-values.yaml"
gomplate -f "workspace-pipeline/values-template.yaml" -o "workspace-pipeline/generated-values.yaml"
gomplate -f "workspace-dependencies/workspace-ingress-policy-template.yaml" -o "workspace-dependencies/generated-workspace-ingress-policy.yaml"
gomplate -f "workspace-api/iam-template.yaml" -o "workspace-api/generated-iam.yaml"


envsubst < "workspace-dependencies/workspace-session-iam-policy-template.yaml" > "workspace-dependencies/generated-workspace-session-iam-policy.yaml"

echo ""
echo "✅ Configuration complete!"
echo "Please proceed to apply the necessary Kubernetes secrets before deploying."