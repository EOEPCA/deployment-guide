#!/bin/bash
source ../../common/utils.sh
echo "Configuring OpenEO..."

# First, ask which backend to use
ask "OPENEO_BACKEND" "Which OpenEO backend would you like to deploy? (geotrellis/dask)" "geotrellis" is_valid_backend

function is_valid_backend() {
    [[ "$1" == "geotrellis" || "$1" == "dask" ]]
}

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Enter the storage class name" "standard" is_non_empty
configure_cert

# if [ -z "$OIDC_ISSUER_URL" ]; then
#     echo "⚠️   An OIDC Provider is required to submit jobs. Please ensure that an OIDC Provider is accessible."
#     echo ""
#     source ../../common/prerequisite-utils.sh
#     check_oidc_provider_accessible
# fi

ask "OPENEO_ENABLE_OIDC" "Enable OIDC authentication for OpenEO? (yes/no)" "yes" is_yes_no

if [[ "$OPENEO_ENABLE_OIDC" == "yes" ]]; then
    ask "OPENEO_CLIENT_ID" "Enter the Client ID (OIDC public client) that will be created for OpenEO clients" "openeo-public"
fi

# Backend-specific configuration
if [[ "$OPENEO_BACKEND" == "dask" ]]; then
    echo ""
    echo "📊 Configuring Dask Backend..."
    
    ask "DASK_GATEWAY_ENABLED" "Deploy Dask Gateway? (yes/no - select 'no' if already deployed)" "yes" is_yes_no
    
    if [[ "$DASK_GATEWAY_ENABLED" == "yes" ]]; then
        ask "DASK_GATEWAY_NAMESPACE" "Enter namespace for Dask Gateway" "dask-gateway" is_non_empty
        ask "DASK_GATEWAY_PASSWORD" "Enter password for Dask Gateway" "changeme" is_non_empty
    else
        ask "DASK_GATEWAY_URL" "Enter existing Dask Gateway URL" "http://dask-gateway.dask-gateway:80" is_non_empty
        ask "DASK_GATEWAY_PASSWORD" "Enter password for existing Dask Gateway" "" is_non_empty
    fi
    
    ask "DASK_WORKER_CORES" "Default CPU cores per Dask worker" "2" is_number
    ask "DASK_WORKER_MEMORY" "Default memory per Dask worker (e.g., 4Gi)" "4Gi" is_non_empty
    ask "DASK_MAX_WORKERS" "Maximum number of Dask workers" "10" is_number
    
    # S3 configuration for data access
    ask "S3_ENDPOINT" "S3 endpoint for data access" "http://minio.minio.svc.cluster.local:9000" is_non_empty
    ask "S3_ACCESS_KEY" "S3 access key" "minioadmin" is_non_empty
    ask "S3_SECRET_KEY" "S3 secret key" "minioadmin" is_non_empty
    ask "S3_REGION" "S3 region" "us-east-1" is_non_empty
    
    # STAC configuration
    ask "STAC_CATALOG_URL" "STAC catalog URL (optional, leave empty to skip)" "" is_optional
    
    # Generate Dask backend templates
    gomplate -f "openeo-dask/$TEMPLATE_PATH" -o "openeo-dask/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    gomplate -f "openeo-dask/$INGRESS_TEMPLATE_PATH" -o "openeo-dask/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    
    if [[ "$DASK_GATEWAY_ENABLED" == "yes" ]]; then
        gomplate -f "openeo-dask/dask-gateway-values-template.yaml" -o "openeo-dask/dask-gateway-values.yaml"
    fi
    
elif [[ "$OPENEO_BACKEND" == "geotrellis" ]]; then
    echo ""
    echo "🌍 Configuring GeoTrellis Backend..."
    
    # Generate GeoTrellis backend templates (existing code)
    gomplate -f "openeo-geotrellis/$TEMPLATE_PATH" -o "openeo-geotrellis/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    gomplate -f "sparkoperator/$TEMPLATE_PATH" -o "sparkoperator/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    gomplate -f "zookeeper/$TEMPLATE_PATH" -o "zookeeper/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    gomplate -f "openeo-geotrellis/$INGRESS_TEMPLATE_PATH" -o "openeo-geotrellis/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

echo "✅ OpenEO ($OPENEO_BACKEND backend) configured, please proceed following the guide."