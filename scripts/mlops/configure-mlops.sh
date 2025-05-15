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
ask "S3_REGION" "Enter the S3 region" "us-east-1" is_non_empty
ask "S3_ACCESS_KEY" "Enter the MinIO access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the MinIO secret key" "" is_non_empty
ask "S3_BUCKET_SHARINGHUB" "Enter the S3 bucket name for SharingHub" "mlopbb-sharinghub" is_non_empty
ask "S3_BUCKET_MLFLOW" "Enter the S3 bucket name for MLFlow" "mlopbb-mlflow-sharinghub" is_non_empty

# OIDC configuration
if [ "$INGRESS_CLASS" == "apisix" ]; then
    ask "MLOPS_OIDC_ENABLED" "Enable OIDC for GitLab and SharingHub (true/false)" "true" is_boolean
elif [ "$INGRESS_CLASS" == "nginx" ]; then
    MLOPS_OIDC_ENABLED=false
fi

if [ "$MLOPS_OIDC_ENABLED" == "true" ]; then
    echo "OIDC is enabled. Please provide the following details:"
    ask "OIDC_ISSUER_URL" "Enter the OIDC issuer URL" "$HTTP_SCHEME://${KEYCLOAK_HOST}/realms/${REALM}" is_non_empty
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

if [ -z "$MLFLOW_POSTGRES_USERNAME" ]; then
    add_to_state_file "MLFLOW_POSTGRES_USERNAME" "postgres"
fi

if [ -z "$MLFLOW_POSTGRES_PASSWORD" ]; then
    MLFLOW_POSTGRES_PASSWORD=$(generate_aes_key 32)
    add_to_state_file "MLFLOW_POSTGRES_PASSWORD" "$MLFLOW_POSTGRES_PASSWORD"
fi

# Generate configuration files for GitLab, SharingHub, and MLflow SharingHub
gomplate  -f "gitlab/$TEMPLATE_PATH" -o "gitlab/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "sharinghub/$TEMPLATE_PATH" -o "sharinghub/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "mlflow/$TEMPLATE_PATH" -o "mlflow/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"


# Generate configuration files for secrets
gomplate -f "mlflow/pvc-template.yaml" -o "mlflow/generated-pvc.yaml" --datasource omniauth="gitlab/omniauth.yaml"
gomplate -f "gitlab/storage.config.template" -o "gitlab/storage.config"
gomplate -f "gitlab/lfs-s3.yaml.template" -o "gitlab/lfs-s3.yaml"

if [ "$MLOPS_OIDC_ENABLED" == "true" ]; then
    gomplate -f "gitlab/provider.yaml.template" -o "gitlab/provider.yaml"
fi

if [ "$INGRESS_CLASS" == "apisix" ]; then
    gomplate -f "sharinghub/$INGRESS_TEMPLATE_PATH" -o "sharinghub/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

gomplate -f "mlflow/$INGRESS_TEMPLATE_PATH" -o "mlflow/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
