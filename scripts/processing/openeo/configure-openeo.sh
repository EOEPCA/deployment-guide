
#!/bin/bash
source ../../common/utils.sh
echo "Configuring openEO..."

echo "⚠️   An OIDC Provider is required to submit jobs. Please ensure that an OIDC Provider is accessible. If you have one, ignore this message, otherwise consult the guide."
echo ""

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Enter the storage class name" "standard" is_non_empty
configure_cert

if [ -z "$OIDC_ISSUER_URL" ]; then
    source ../../common/prerequisite-utils.sh
    check_oidc_provider_accessible
fi

ask "OPENEO_CLIENT_ID" "Enter the Client ID (Keycloak OIDC public client) that will be created for openEO clients" "openeo-public"

envsubst <"openeo-geotrellis/values-template.yaml" >"openeo-geotrellis/generated-values.yaml"
envsubst <"sparkoperator/values-template.yaml" >"sparkoperator/generated-values.yaml"
envsubst <"zookeeper/values-template.yaml" >"zookeeper/generated-values.yaml"

envsubst <"openeo-geotrellis/ingress-template.yaml" >"openeo-geotrellis/generated-ingress.yaml"

echo "✅ openEO configured, please proceed following the guide."
