#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the MLOps Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

# S3 configuration
ask "S3_ENDPOINT" "Enter the S3 endpoint URL" "$HTTP_SCHEME://minio.${INGRESS_HOST}" is_non_empty
ask "S3_BUCKET" "Enter the S3 bucket name" "mlops-bucket" is_non_empty
ask "S3_REGION" "Enter the S3 region" "us-east-1" is_non_empty
ask "S3_ACCESS_KEY" "Enter the MinIO access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the MinIO secret key" "" is_non_empty

# OIDC configuration
ask "MLOPS_OIDC_ENABLED" "Enable OIDC for GitLab and SharingHub (true/false)" "true" is_boolean

if [ "$MLOPS_OIDC_ENABLED" == "true" ]; then
    echo "OIDC is enabled. Please provide the following details:"
    ask "MLOPS_OIDC_ISSUER_URL" "Enter the OIDC issuer URL" "$HTTP_SCHEME://${KEYCLOAK_HOST}/realms/${REALM}" is_non_empty
    ask "MLOPS_OIDC_CLIENT_ID" "Enter the OIDC client ID for GitLab" "gitlab" is_non_empty

    if [ -z "$MLOPS_OIDC_CLIENT_SECRET" ]; then
        MLOPS_OIDC_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "MLOPS_OIDC_CLIENT_SECRET" "$MLOPS_OIDC_CLIENT_SECRET"
    fi
    echo ""
    echo "❗  Generated client secret for the MLOps."
    echo "   Please store this securely: $MLOPS_OIDC_CLIENT_SECRET"
    echo ""
fi

# Generate secret keys and store them in the state file
if [ -z "$SHARINGHUB_SESSION_SECRET" ]; then
    add_to_state_file "SHARINGHUB_SESSION_SECRET" "$(generate_aes_key 32)"
fi
if [ -z "$MLFLOW_SECRET_KEY" ]; then
    add_to_state_file "MLFLOW_SECRET_KEY" "$(generate_aes_key 32)"
fi

# Generate configuration files for GitLab, SharingHub, and MLflow SharingHub
envsubst <"gitlab/values-template.yaml" >"gitlab/generated-values.yaml"
envsubst <"sharinghub/values-template.yaml" >"sharinghub/generated-values.yaml"
envsubst <"mlflow/values-template.yaml" >"mlflow/generated-values.yaml"
envsubst <"mlflow/pvc-template.yaml" >"mlflow/generated-pvc.yaml"

# Generate configuration files for secrets
envsubst <"gitlab/storage.config.template" >"gitlab/storage.config"
envsubst <"gitlab/lfs-s3.yaml.template" >"gitlab/lfs-s3.yaml"
envsubst <"gitlab/provider.yaml.template" >"gitlab/provider.yaml"

# Ingress
envsubst <"sharinghub/$INGRESS_TEMPLATE_PATH" >"sharinghub/$INGRESS_OUTPUT_PATH"
envsubst <"mlflow/$INGRESS_TEMPLATE_PATH" >"mlflow/$INGRESS_OUTPUT_PATH"
