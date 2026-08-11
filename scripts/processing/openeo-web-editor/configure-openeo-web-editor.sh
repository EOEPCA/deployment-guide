#!/bin/bash
source ../../common/utils.sh
echo "Configuring the openEO Web Editor..."

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
configure_cert

ask "OPENEO_WEB_EDITOR_HOST" "Enter the full host domain for the Web Editor" "editor.${INGRESS_HOST}" is_valid_domain

gomplate -f "values-template.yaml" -o "generated-values.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ openEO Web Editor configured successfully."
echo "📝 Configuration saved to generated-values.yaml"
echo "Please proceed with the deployment steps in the guide."
