
#!/bin/bash
source ../common/utils.sh
echo "Configuring openEO..."

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
configure_cert

envsubst <"openeo-aggregator/values-template.yaml" >"openeo-aggregator/generated-values.yaml"
envsubst <"openeo-geotrellis/values-template.yaml" >"openeo-geotrellis/generated-values.yaml"
envsubst <"sparkoperator/values-template.yaml" >"sparkoperator/generated-values.yaml"
envsubst <"zookeeper/values-template.yaml" >"zookeeper/generated-values.yaml"

envsubst <"openeo-geotrellis/ingress-template.yaml" >"openeo-geotrellis/generated-ingress.yaml"

echo "✅ openEO configured, please proceed following the guide."
