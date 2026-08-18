#!/bin/bash

source ../common/utils.sh

echo "Configuring the Data Access Building Block..."

ask "S3_HOST" "Enter the S3 Host URL (excluding https)" "minio.${INGRESS_HOST}" is_non_empty
ask "S3_ACCESS_KEY" "Enter the S3 (MinIO) access key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the S3 (MinIO) secret key" "" is_non_empty

ask "USE_EXTERNAL_POSTGRES" "Use external PostgreSQL with External Secrets Operator? (yes/no)" "no" is_yes_no
if [ "$USE_EXTERNAL_POSTGRES" = "yes" ]; then
    ask "POSTGRES_EXTERNAL_SECRET_NAME" "Enter the external secret name for PostgreSQL" "default-pguser-eoapi" is_non_empty
else
    ask "POSTGRES_REPLICAS" "Number of PostgreSQL replicas" "1" is_number
    ask "POSTGRES_STORAGE_SIZE" "PostgreSQL storage size (e.g. 1Gi)" "1Gi" is_non_empty
fi

# App-native OIDC (not an ingress-layer plugin), so this works under both apisix and nginx.
ask "DATA_ACCESS_ENABLE_IAM" "Enable IAM/Keycloak integration? (yes/no)" "no" is_yes_no
if [ "$DATA_ACCESS_ENABLE_IAM" = "yes" ]; then
    ask "KEYCLOAK_HOST" "Enter the Keycloak full host domain excluding https (e.g., auth.example.com)" "auth.${INGRESS_HOST}" is_valid_domain
    ask "REALM" "Enter the Keycloak realm" "eoepca" is_non_empty
    ask "EOAPI_CLIENT_ID" "Enter Keycloak client ID for EOAPI" "eoapi" is_non_empty
else
    # Without IAM, protect the openEO API with basic auth instead of leaving it open.
    ask "OPENEO_BASIC_AUTH_USER" "Enter a username to protect the openEO API (no IAM)" "openeo" is_non_empty
    if [ -z "${OPENEO_BASIC_AUTH_PASSWORD:-}" ]; then
        export OPENEO_BASIC_AUTH_PASSWORD="$(generate_password)"
        add_to_state_file "OPENEO_BASIC_AUTH_PASSWORD" "$OPENEO_BASIC_AUTH_PASSWORD"
    fi
fi

ask "ENABLE_TRANSACTIONS" "Enable STAC transactions extension? (yes/no)" "yes" is_yes_no
ask "ENABLE_EOAPI_NOTIFIER" "Enable EOAPI notifier for CloudEvents? (yes/no)" "no" is_yes_no

# Geoparquet export (optional): periodically exports pgSTAC collections/items
# to geoparquet on an S3 bucket. Reuses the same S3 credentials as raster/multidim.
ask "ENABLE_GEOPARQUET_EXPORT" "Enable scheduled pgSTAC-to-geoparquet export to S3? (yes/no)" "no" is_yes_no
if [ "$ENABLE_GEOPARQUET_EXPORT" = "yes" ]; then
    ask "GEOPARQUET_EXPORT_S3_BUCKET" "Enter the S3 path for exported geoparquet (e.g. s3://bucket/geoparquet)" "s3://geoparquet-exporter/geoparquet" is_non_empty
fi

# Allow override for public-facing host through which eoAPI is accessed
export EOAPI_PUBLIC_HOST="${EOAPI_PUBLIC_HOST:-"eoapi.${INGRESS_HOST}"}"

echo "Generating configuration files..."

gomplate -f "eoapi/$TEMPLATE_PATH" -o "eoapi/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

if [ "$USE_EXTERNAL_POSTGRES" != "yes" ]; then
    gomplate -f "postgres/$TEMPLATE_PATH" -o "postgres/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

gomplate -f "eoapi-support/$TEMPLATE_PATH" -o "eoapi-support/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "stac-manager/$TEMPLATE_PATH" -o "stac-manager/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "titiler-openeo/$TEMPLATE_PATH" -o "titiler-openeo/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

if [ "$INGRESS_CLASS" == "apisix" ]; then
    gomplate -f "eoapi/$INGRESS_TEMPLATE_PATH" -o "eoapi/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

if [ "$USE_EXTERNAL_POSTGRES" = "yes" ]; then
    gomplate -f "external-secrets/eso-pgo-template.yaml" -o "external-secrets/eso-pgo-values.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

if [ "$DATA_ACCESS_ENABLE_IAM" = "yes" ]; then
    gomplate -f "iam/iam-template.yaml" -o "iam/generated-iam.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

if [ "$ENABLE_GEOPARQUET_EXPORT" = "yes" ]; then
    gomplate -f "geoparquet-exporter/$TEMPLATE_PATH" -o "geoparquet-exporter/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

echo "Configuration complete!"

if [ "$DATA_ACCESS_ENABLE_IAM" != "yes" ]; then
    echo ""
    echo "🔐 IMPORTANT: openEO API basic-auth credentials (no IAM):"
    echo "  Username: $OPENEO_BASIC_AUTH_USER"
    echo "  Password: $OPENEO_BASIC_AUTH_PASSWORD"
fi
