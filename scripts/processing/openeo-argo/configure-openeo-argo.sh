#!/bin/bash
source ../../common/utils.sh
echo "Configuring OpenEO ArgoWorkflows with Dask..."

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for persistent data" "standard" is_non_empty
configure_cert

echo ""
echo "🔐 Configuring Authentication..."
ask "OIDC_ISSUER_URL" "Enter OIDC issuer URL" "${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}" is_valid_url
ask "OIDC_ORGANISATION" "Enter OIDC organisation" "eoepca" is_non_empty
ask "OIDC_POLICIES" "Enter OIDC policies (optional, leave empty for none)" "" is_optional

echo ""
echo "🗂️ Configuring Data Sources..."
ask "STAC_CATALOG_ENDPOINT" "STAC catalog URL" "${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/stac" is_non_empty

# Generate configuration files
gomplate -f "values-template.yaml" -o "generated-values.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "ingress-template.yaml" -o "generated-ingress.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ OpenEO ArgoWorkflows (Dask backend) configured successfully."
echo "📝 Configuration saved to generated-values.yaml"
echo "Please proceed with the deployment steps in the guide."