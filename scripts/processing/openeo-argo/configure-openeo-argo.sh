#!/bin/bash
source ../../common/utils.sh
echo "Configuring OpenEO ArgoWorkflows with Dask..."

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for persistent data" "standard" is_non_empty
configure_cert

echo ""
echo "🔐 Configuring Authentication..."
ask "OPENEO_ARGO_ENABLE_OIDC" "Enable OIDC authentication? (yes/no)" "yes" is_yes_no
if [ "$OPENEO_ARGO_ENABLE_OIDC" == "no" ]; then
    echo "⚠️  NOTE: This deployment uses basic authentication for testing only!"
    echo "         For production, use proper OIDC authentication"
    export OPENEO_ARGO_BASIC_AUTH_USERNAME="eoepcauser"
    export OPENEO_ARGO_BASIC_AUTH_PASSWORD="eoepcapass"
    BASIC_AUTH_HASH=$(openssl passwd -apr1 "${OPENEO_ARGO_BASIC_AUTH_PASSWORD}")
    export OPENEO_ARGO_BASIC_AUTH_HTPASSWD="${OPENEO_ARGO_BASIC_AUTH_USERNAME}:${BASIC_AUTH_HASH}"
    # Add base64 encoding for the Authorization header
    export OPENEO_ARGO_BASIC_AUTH_B64=$(echo -n "${OPENEO_ARGO_BASIC_AUTH_USERNAME}:${OPENEO_ARGO_BASIC_AUTH_PASSWORD}" | base64)
    add_to_state_file "OPENEO_ARGO_BASIC_AUTH_HTPASSWD" "$OPENEO_ARGO_BASIC_AUTH_HTPASSWD"
    add_to_state_file "OPENEO_ARGO_BASIC_AUTH_B64" "$OPENEO_ARGO_BASIC_AUTH_B64"
fi
if [ "$OPENEO_ARGO_ENABLE_OIDC" == "yes" ]; then
    ask "OIDC_ISSUER_URL" "Enter OIDC issuer URL" "${HTTP_SCHEME}://auth.${INGRESS_HOST}/realms/${REALM}" is_valid_url
    ask "OIDC_ORGANISATION" "Enter OIDC organisation" "eoepca" is_non_empty
    ask "OIDC_POLICIES" "Enter OIDC policies (optional, leave empty for none)" "" is_optional
fi

echo ""
echo "🗂️ Configuring Data Sources..."
ask "STAC_CATALOG_ENDPOINT" "STAC catalog URL" "${HTTP_SCHEME}://eoapi.${INGRESS_HOST}/stac" is_non_empty

# Generate configuration files
gomplate -f "values-template.yaml" -o "generated-values.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "ingress-template.yaml" -o "generated-ingress.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

if [ "$OPENEO_ARGO_ENABLE_OIDC" == "no" ]; then
    gomplate -f "proxy-auth-template.yaml" -o "generated-proxy-auth.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi


echo "✅ OpenEO ArgoWorkflows (Dask backend) configured successfully."
echo "📝 Configuration saved to generated-values.yaml"
echo "Please proceed with the deployment steps in the guide."