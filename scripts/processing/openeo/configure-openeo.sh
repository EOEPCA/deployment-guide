#!/bin/bash
source ../../common/utils.sh
echo "Configuring OpenEO..."

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
configure_cert

ask "OPENEO_ENABLE_OIDC" "Enable OIDC authentication for OpenEO? (yes/no)" "yes" is_yes_no
if [[ "$OPENEO_ENABLE_OIDC" == "yes" ]]; then
    source ../../common/prerequisite-utils.sh
    run_validation "check_crossplane_installed"

    ask "OPENEO_CLIENT_ID" "Enter the Client ID (OIDC public client) that will be created for OpenEO clients" "openeo-public"
fi

gomplate -f "openeo-geotrellis/$TEMPLATE_PATH" -o "openeo-geotrellis/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "sparkoperator/$TEMPLATE_PATH" -o "sparkoperator/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "zookeeper/$TEMPLATE_PATH" -o "zookeeper/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "openeo-geotrellis/$INGRESS_TEMPLATE_PATH" -o "openeo-geotrellis/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

if [[ "$OPENEO_ENABLE_OIDC" == "yes" ]]; then
    gomplate -f "openeo-geotrellis/iam-template.yaml" -o "openeo-geotrellis/generated-iam.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

echo "✅ OpenEO (geotrellis backend) configured, please proceed following the guide."