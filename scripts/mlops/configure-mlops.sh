#!/bin/bash

source ../common/utils.sh
echo "Configuring the MLOps Building Block..."

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
configure_cert

ask "S3_ENDPOINT" "Enter the S3 endpoint URL" "$HTTP_SCHEME://minio.${INGRESS_HOST}" is_non_empty
ask "S3_REGION" "Enter the S3 region" "us-east-1" is_non_empty
ask "S3_ACCESS_KEY" "Enter the MinIO access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the MinIO secret key" "" is_non_empty

# As part of the Deployment Guide, MinIO has created two buckets for SharingHub and MLflow SharingHub.
S3_BUCKET_SHARINGHUB="mlopsbb-sharinghub"
S3_BUCKET_MLFLOW="mlopsbb-mlflow-sharinghub"
add_to_state_file "S3_BUCKET_SHARINGHUB" "$S3_BUCKET_SHARINGHUB"
add_to_state_file "S3_BUCKET_MLFLOW" "$S3_BUCKET_MLFLOW"

ask "MLOPS_OIDC_ENABLED" "Enable OIDC for GitLab and SharingHub (true/false)" "true" is_boolean

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

gomplate -f "gitlab/values-template.yaml" -o "gitlab/generated-values.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "sharinghub/values-template.yaml" -o "sharinghub/generated-values.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "mlflow/values-template.yaml" -o "mlflow/generated-values.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "mlflow/postgres-deployment-template.yaml" -o "mlflow/postgres-deployment.yaml"

gomplate -f "gitlab/storage.config.template" -o "gitlab/storage.config"
gomplate -f "gitlab/lfs-s3.yaml.template" -o "gitlab/lfs-s3.yaml"

if [ "$MLOPS_OIDC_ENABLED" == "true" ]; then
    gomplate -f "gitlab/provider.yaml.template" -o "gitlab/provider.yaml"
fi

if [ "$INGRESS_CLASS" == "apisix" ]; then
    gomplate -f "sharinghub/$INGRESS_TEMPLATE_PATH" -o "sharinghub/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

gomplate -f "mlflow/$INGRESS_TEMPLATE_PATH" -o "mlflow/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

if [ "$MLOPS_OIDC_ENABLED" == "true" ]; then
    source ../common/prerequisite-utils.sh
    run_validation "check_crossplane_installed"

    gomplate -f "iam-template.yaml" -o "generated-iam.yaml"
fi
