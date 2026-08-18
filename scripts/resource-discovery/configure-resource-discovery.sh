#!/bin/bash

source ../common/utils.sh

echo "Configuring the Resource Discovery..."

# IAM is optional. Protected Resource Discovery currently requires APISIX because
# the protected route uses APISIX openid-connect and opa plugins.
ask "RESOURCE_DISCOVERY_ENABLE_IAM" "Enable IAM-protected transactional catalogue? (yes/no)" "no" is_yes_no

if [ "${RESOURCE_DISCOVERY_ENABLE_IAM}" = "yes" ] && [ "${INGRESS_CLASS}" != "apisix" ]; then
  echo "❌ IAM-protected Resource Discovery currently requires INGRESS_CLASS=apisix."
  echo "   Re-run the configuration and select APISIX, or set RESOURCE_DISCOVERY_ENABLE_IAM=no."
  exit 1
fi

if [ -z "${RESOURCE_DISCOVERY_DB_PASSWORD:-}" ]; then
  RESOURCE_DISCOVERY_DB_PASSWORD="$(generate_password)"
  add_to_state_file "RESOURCE_DISCOVERY_DB_PASSWORD" "$RESOURCE_DISCOVERY_DB_PASSWORD"
fi
export RESOURCE_DISCOVERY_DB_PASSWORD

if [ "${RESOURCE_DISCOVERY_ENABLE_IAM}" = "yes" ]; then
  if [ -z "${RESOURCE_CATALOGUE_SESSION_SECRET:-}" ]; then
    RESOURCE_CATALOGUE_SESSION_SECRET="$(generate_aes_key 32)"
    add_to_state_file "RESOURCE_CATALOGUE_SESSION_SECRET" "$RESOURCE_CATALOGUE_SESSION_SECRET"
  fi
  export RESOURCE_CATALOGUE_SESSION_SECRET
fi

gomplate \
  -f "$TEMPLATE_PATH" \
  -o "$OUTPUT_PATH" \
  --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

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

  gomplate \
    -f db-secret-template.yaml \
    -o generated-db-secret.yaml \
    --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

echo "✅ Configuration files generated."