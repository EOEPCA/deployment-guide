#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Data Access Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty

# Configure certificate settings
configure_cert

# S3/Object Storage Configuration
ask "S3_HOST" "Enter the S3 Host URL (excluding https)" "minio.${INGRESS_HOST}" is_non_empty
ask "S3_ACCESS_KEY" "Enter the S3 (MinIO) access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the S3 (MinIO) secret key" "" is_non_empty
ask "S3_ENDPOINT" "Enter the S3 endpoint for EOAPI (e.g. eodata.cloudferro.com)" "minio.${INGRESS_HOST}" is_non_empty

# PostgreSQL Configuration
ask "USE_EXTERNAL_POSTGRES" "Use external PostgreSQL with External Secrets Operator? (yes/no)" "no" is_yes_no
if [ "$USE_EXTERNAL_POSTGRES" = "yes" ]; then
    ask "POSTGRES_EXTERNAL_SECRET_NAME" "Enter the external secret name for PostgreSQL" "default-pguser-eoapi" is_non_empty
else
    ask "POSTGRES_REPLICAS" "Number of PostgreSQL replicas" "1" is_number
    ask "POSTGRES_STORAGE_SIZE" "PostgreSQL storage size (e.g. 1Gi)" "1Gi" is_non_empty
fi

# IAM/Keycloak Configuration
ask "DATA_ACCESS_ENABLE_IAM" "Enable IAM/Keycloak integration? (yes/no)" "no" is_yes_no
if [ "$DATA_ACCESS_ENABLE_IAM" = "yes" ]; then
    ask "KEYCLOAK_URL" "Enter Keycloak URL" "https://iam-auth.${INGRESS_HOST}" is_non_empty
    ask "KEYCLOAK_REALM" "Enter Keycloak realm" "eoepca" is_non_empty
    ask "KEYCLOAK_CLIENT_ID" "Enter Keycloak client ID for EOAPI" "eoapi" is_non_empty
    ask "OPA_URL" "Enter OPA URL for authorization" "http://iam-opa.iam:8181" is_non_empty
fi

# EOAPI Configuration
ask "ENABLE_TRANSACTIONS" "Enable STAC transactions extension? (yes/no)" "yes" is_yes_no
ask "ENABLE_EOAPI_NOTIFIER" "Enable EOAPI notifier for CloudEvents? (yes/no)" "no" is_yes_no

# Generate templated configuration files
echo "Generating configuration files..."

# Generate main eoapi values
gomplate -f "eoapi/$TEMPLATE_PATH" -o "eoapi/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

# Generate PostgreSQL configuration
if [ "$USE_EXTERNAL_POSTGRES" != "yes" ]; then
    gomplate -f "postgres/$TEMPLATE_PATH" -o "postgres/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

# Generate supporting services configuration
gomplate -f "eoapi-support/$TEMPLATE_PATH" -o "eoapi-support/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "stac-manager/$TEMPLATE_PATH" -o "stac-manager/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "eoapi-maps-plugin/$TEMPLATE_PATH" -o "eoapi-maps-plugin/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

# Generate ingress/routes based on ingress controller
if [ "$INGRESS_CLASS" == "apisix" ]; then
    if [ "$DATA_ACCESS_ENABLE_IAM" = "yes" ]; then
        gomplate -f "routes/$APISIX_ROUTE_TEMPLATE_PATH" -o "routes/$APISIX_ROUTE_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    else
        gomplate -f "eoapi/$INGRESS_TEMPLATE_PATH" -o "eoapi/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    fi
fi

# Generate External Secrets configuration if using external PostgreSQL
if [ "$USE_EXTERNAL_POSTGRES" = "yes" ]; then
    gomplate -f "external-secrets/eso-pgo-template.yaml" -o "external-secrets/eso-pgo-values.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

# Generate IAM resources if enabled
if [ "$DATA_ACCESS_ENABLE_IAM" = "yes" ]; then
    gomplate -f "iam/iam-template.yaml" -o "iam/generated-iam" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

echo "Configuration complete!"
