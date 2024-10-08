#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the MLOps Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty

# S3 configuration
ask "S3_ENDPOINT" "Enter the S3 endpoint URL" "https://minio.example.com" is_non_empty
ask "S3_BUCKET" "Enter the S3 bucket name" "mlops-bucket" is_non_empty
ask "S3_REGION" "Enter the S3 region" "us-east-1" is_non_empty
ask "S3_ACCESS_KEY" "Enter the MinIO access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the MinIO secret key" "" is_non_empty

# OIDC configuration
ask "OIDC_ISSUER_URL" "Enter the OIDC issuer URL" "https://keycloak.example.com/realms/master" is_non_empty
ask "OIDC_CLIENT_ID" "Enter the OIDC client ID for GitLab" "" is_non_empty
ask "OIDC_CLIENT_SECRET" "Enter the OIDC client secret for GitLab" "" is_non_empty

# Generate secret keys and store them in the state file
if [ -z "$SHARINGHUB_SESSION_SECRET" ]; then
    add_to_state_file "SHARINGHUB_SESSION_SECRET" "$(generate_aes_key 32)"
fi
if [ -z "$MLFLOW_SECRET_KEY" ]; then
    add_to_state_file "MLFLOW_SECRET_KEY" "$(MLOPS_SECRET_KEY)"
fi
if [ -z "$GITLAB_ROOT_PASSWORD" ]; then
    add_to_state_file "GITLAB_ROOT_PASSWORD" "$(generate_password)"
fi


# Generate configuration files for GitLab, SharingHub, and MLflow SharingHub
envsubst <"gitlab/values-template.yaml" >"gitlab/generated-values.yaml"
envsubst <"sharinghub/values-template.yaml" >"sharinghub/generated-values.yaml"
envsubst <"mlflow/values-template.yaml" >"mlflow/generated-values.yaml"

# Generate configuration files for secrets
envsubst <"gitlab/storage.config.template" >"gitlab/storage.config"
envsubst <"gitlab/lfs-s3.yaml.template" >"gitlab/lfs-s3.yaml"
envsubst <"gitlab/provider.yaml.template" >"gitlab/provider.yaml"

# Create namespaces if they don't exist
# kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -
# kubectl create namespace sharinghub --dry-run=client -o yaml | kubectl apply -f -

echo "Please proceed to create the required Kubernetes secrets before deploying GitLab."