#!/bin/bash
source ../../common/utils.sh
echo "Configuring OpenEO ArgoWorkflows with Dask..."

ask "SHARED_STORAGECLASS" "Specify the Kubernetes storage class for the SHARED job workspace (ReadWriteMany)" "standard" is_non_empty

echo ""
echo "🔐 Configuring Authentication..."
source ../../common/prerequisite-utils.sh
run_validation "check_crossplane_installed"

ask "OIDC_ISSUER_URL" "Enter OIDC issuer URL" "${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}" is_valid_domain
ask "OIDC_ORGANISATION" "Enter OIDC organisation" "eoepca" is_non_empty
ask "OIDC_POLICIES" "Enter OIDC policies (optional, leave empty for none)" "" is_optional

echo ""
echo "🗂️ Configuring Data Sources..."
ask "STAC_CATALOG_ENDPOINT" "STAC catalog URL" "${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/stac" is_non_empty

gomplate -f "values-template.yaml" -o "generated-values.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "ingress-template.yaml" -o "generated-ingress.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "iam-template.yaml" -o "generated-iam.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ OpenEO ArgoWorkflows (Dask backend) configured successfully."
echo "📝 Configuration saved to generated-values.yaml"
echo "Please proceed with the deployment steps in the guide."
