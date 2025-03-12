
#!/bin/bash
source ../../common/utils.sh
echo "Configuring openEO..."

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Enter the storage class name" "standard" is_non_empty
configure_cert

if [ -z "$OIDC_ISSUER_URL" ]; then
    echo "⚠️   An OIDC Provider is required to submit jobs. Please ensure that an OIDC Provider is accessible. If you have one, ignore this message, otherwise consult the guide."
    echo ""
    source ../../common/prerequisite-utils.sh
    check_oidc_provider_accessible
fi

ask "OPENEO_CLIENT_ID" "Enter the Client ID (Keycloak OIDC public client) that will be created for openEO clients" "openeo-public"

gomplate -f "openeo-geotrellis/$TEMPLATE_PATH" -o "openeo-geotrellis/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "sparkoperator/$TEMPLATE_PATH" -o "sparkoperator/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "zookeeper/$TEMPLATE_PATH" -o "zookeeper/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

gomplate -f "openeo-geotrellis/$INGRESS_TEMPLATE_PATH" -o "openeo-geotrellis/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ openEO configured, please proceed following the guide."
