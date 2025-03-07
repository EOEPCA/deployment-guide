#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Data Access Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

ask "S3_HOST" "Enter the S3 Host URL (excluding https)" "minio.${INGRESS_HOST}" is_non_empty
ask "S3_ACCESS_KEY" "Enter the S3 (MinIO) access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the S3 (MinIO) secret key" "" is_non_empty


gomplate  -f "eoapi/$TEMPLATE_PATH" -o "eoapi/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "stacture/$TEMPLATE_PATH" -o "stacture/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "postgres/$TEMPLATE_PATH" -o "postgres/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "eoapi-support/$TEMPLATE_PATH" -o "eoapi-support/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

gomplate  -f "eoapi/$INGRESS_TEMPLATE_PATH" -o "eoapi/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
