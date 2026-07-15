#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Workspace Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
configure_cert

# Workspace sessions and API routing rely on ApisixRoute/ApisixPluginConfig,
# so only the APISIX ingress class is currently supported.
if [ "${INGRESS_CLASS}" != "apisix" ]; then
    echo "❌ The Workspace Building Block currently requires INGRESS_CLASS=apisix."
    exit 1
fi

# S3 configuration
ask "S3_ENDPOINT" "Enter the S3 endpoint URL" "$HTTP_SCHEME://minio.${INGRESS_HOST}" is_non_empty
ask "S3_REGION" "Enter the S3 region" "us-east-1" is_non_empty
ask "S3_ACCESS_KEY" "Enter the MinIO access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the MinIO secret key" "" is_non_empty

# Required unconditionally, regardless of OIDC_WORKSPACE_ENABLED below - the
# pipeline uses this client to self-serve Keycloak resources per workspace.
ask "WORKSPACE_PIPELINE_CLIENT_ID" "Enter the Client ID for the Workspace Pipeline" "workspace-pipeline" is_non_empty
if [ -z "$WORKSPACE_PIPELINE_CLIENT_SECRET" ]; then
    WORKSPACE_PIPELINE_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "WORKSPACE_PIPELINE_CLIENT_SECRET" "$WORKSPACE_PIPELINE_CLIENT_SECRET"
fi
echo ""
echo "❗  Generated client secret for the Workspace Pipeline."
echo "   Please store this securely: $WORKSPACE_PIPELINE_CLIENT_SECRET"
echo ""

# Required unconditionally: the Workspace API's own authMode=gateway always
# validates a Bearer token audienced for this client - there is no way to run
# the API without it (see docs step 9.1).
ask "WORKSPACE_API_CLIENT_ID" "Enter the Client ID for the Workspace API" "workspace-api" is_non_empty
if [ -z "$WORKSPACE_API_CLIENT_SECRET" ]; then
    WORKSPACE_API_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "WORKSPACE_API_CLIENT_SECRET" "$WORKSPACE_API_CLIENT_SECRET"
fi
echo ""
echo "❗  Generated client secret for the Workspace API."
echo "   Please store this securely: $WORKSPACE_API_CLIENT_SECRET"
echo ""

# Controls only the ingress-level redirect-to-login convenience and Datalab
# session SSO (see docs step 9.2/9.3) - the Workspace API itself always
# requires a valid Bearer token regardless of this setting.
ask "OIDC_WORKSPACE_ENABLED" "Do you want ingress-level login redirect and Datalab session SSO via Keycloak?" "true" is_boolean

ask "KEYCLOAK_TEST_USER" "Enter the username for the example user" "eoepcauser"
ask "KEYCLOAK_TEST_ADMIN" "Enter the username for the example ADMIN user" "eoepcaadmin"
ask "KEYCLOAK_TEST_PASSWORD" "Enter the password for the example users" "eoepcapassword"

# Deduce the service and pod CIDRs from the cluster, used to scope the
# NetworkPolicy applied to each provisioned Datalab/session pod.
export SERVICE_CIDR=$(kubectl get svc kubernetes -n default -o json | jq -r '.spec.clusterIP' | awk -F. '{printf "%d.%d.0.0/12", $1, $2}')
export POD_CIDRS=$(kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}' | tr ' ' ',')

# Generate configuration files
gomplate -f "workspace-api/values-template.yaml" -o "workspace-api/generated-values.yaml"
gomplate -f "workspace-api/ingress-template.yaml" -o "workspace-api/generated-ingress.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "workspace-dependencies/educates-values-template.yaml" -o "workspace-dependencies/educates-values.yaml"
gomplate -f "workspace-pipeline/values-template.yaml" -o "workspace-pipeline/generated-values.yaml"
gomplate -f "workspace-dependencies/workspace-ingress-policy-template.yaml" -o "workspace-dependencies/generated-workspace-ingress-policy.yaml"
gomplate -f "workspace-api/iam-template.yaml" -o "workspace-api/generated-iam.yaml"

# Not gomplate: this policy's Kyverno rules use their own {{ request.object... }}
# JMESPath templating, which must survive literally into the applied YAML -
# gomplate would try to parse it as its own Go-template expressions and fail.
# envsubst only touches ${VAR}/$VAR shell references, leaving Kyverno's {{ }}
# untouched.
envsubst < "workspace-dependencies/workspace-session-iam-policy-template.yaml" > "workspace-dependencies/generated-workspace-session-iam-policy.yaml"

echo ""
echo "✅ Configuration complete!"
echo "Please proceed to apply the necessary Kubernetes secrets before deploying."