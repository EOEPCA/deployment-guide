#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring the Resource Discovery..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty

# IAM is optional. Protected Resource Discovery currently requires APISIX because
# the protected route uses APISIX openid-connect and opa plugins.
ask "RESOURCE_DISCOVERY_ENABLE_IAM" "Enable IAM-protected transactional catalogue? (yes/no)" "no" is_yes_or_no

configure_cert

if [ "${RESOURCE_DISCOVERY_ENABLE_IAM}" = "yes" ] && [ "${INGRESS_CLASS}" != "apisix" ]; then
  echo "❌ IAM-protected Resource Discovery currently requires INGRESS_CLASS=apisix."
  echo "   Re-run the configuration and select APISIX, or set RESOURCE_DISCOVERY_ENABLE_IAM=no."
  exit 1
fi

# Template - helm values for public catalogue
gomplate \
  -f "$TEMPLATE_PATH" \
  -o "$OUTPUT_PATH" \
  --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

# Template - ingress controller for public catalogue
if [ "$INGRESS_CLASS" == "apisix" ]; then
  gomplate \
    -f "$INGRESS_TEMPLATE_PATH" \
    -o "$INGRESS_OUTPUT_PATH" \
    --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
elif [ "$INGRESS_CLASS" == "nginx" ]; then
  NGINX_INGRESS_TEMPLATE_PATH="$(dirname "${INGRESS_TEMPLATE_PATH}")/nginx-$(basename "${INGRESS_TEMPLATE_PATH}")"
  gomplate \
    -f "$NGINX_INGRESS_TEMPLATE_PATH" \
    -o "$INGRESS_OUTPUT_PATH" \
    --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

echo "✅ Configuration file generated: $OUTPUT_PATH"
echo "✅ Configuration file generated: $INGRESS_OUTPUT_PATH"

# IAM/protected catalogue templates are rendered only for APISIX + IAM.
if [ "${RESOURCE_DISCOVERY_ENABLE_IAM}" = "yes" ]; then
  gomplate \
    -f protected-values-template.yaml \
    -o generated-protected-values.yaml \
    --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

  gomplate \
    -f protected-ingress-template.yaml \
    -o generated-protected-ingress.yaml \
    --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

  gomplate \
    -f iam-template.yaml \
    -o generated-iam.yaml \
    --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

  echo "✅ Configuration file generated: generated-protected-values.yaml"
  echo "✅ Configuration file generated: generated-protected-ingress.yaml"
  echo "✅ Configuration file generated: generated-iam.yaml"
fi