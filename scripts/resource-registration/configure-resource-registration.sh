# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Registration Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
ask "SHARED_STORAGECLASS" "Specify the Kubernetes storage class for SHARED data (ReadWriteMany)" "standard" is_non_empty
configure_cert

ask "OPERATON_ADMIN_USER" "Set what you'd like your Operaton (BPM engine) admin username to be" "eoepca" is_non_empty
ask "OPERATON_ADMIN_PASSWORD" "Set what you'd like your Operaton (BPM engine) admin password to be" "eoepca" is_non_empty

if [ -z "${OPERATON_DB_PASSWORD:-}" ]; then
  OPERATON_DB_PASSWORD="$(generate_password)"
  add_to_state_file "OPERATON_DB_PASSWORD" "$OPERATON_DB_PASSWORD"
fi

# eodata base URL
ask "EODATA_ASSET_BASE_URL" "Set the base URL through which harvested 'eodata' assets will be accessed" "${HTTP_SCHEME}://eodata.${INGRESS_HOST}/" is_non_empty

# IAM integration
# Two cases:
#   1. We want to protect the Resource Registration endpoints via OIDC
#   2. The Resource Registration needs to connect with other services that are protected via OIDC (e.g., resource-catalogue, eoapi)
ask "RESOURCE_REGISTRATION_ENABLE_OIDC" "Enable OIDC protection for Resource Registration? (yes/no)" "yes" is_yes_no

if [[ "${RESOURCE_REGISTRATION_ENABLE_OIDC:-no}" == "yes" && "${INGRESS_CLASS:-}" != "apisix" ]]; then
  echo "❌ Resource Registration IAM ingress protection currently requires APISIX."
  echo "   Requested: RESOURCE_REGISTRATION_ENABLE_OIDC=yes with INGRESS_CLASS=${INGRESS_CLASS:-unset}"
  echo "   Use APISIX, or set RESOURCE_REGISTRATION_ENABLE_OIDC=no for a minimal nginx deployment."
  exit 1
fi

ask "RESOURCE_REGISTRATION_PROTECTED_TARGETS" "Resource Registration support for protected targets? (yes/no)" "yes" is_yes_no
# If either is yes, we need IAM client credentials
if [[ "$RESOURCE_REGISTRATION_ENABLE_OIDC" == "yes" || "$RESOURCE_REGISTRATION_PROTECTED_TARGETS" == "yes" ]]; then
  ask "RESOURCE_REGISTRATION_IAM_CLIENT_ID" "Enter the IAM Client ID for Resource Registration" "resource-registration" is_non_empty
  if [ -z "${RESOURCE_REGISTRATION_IAM_CLIENT_SECRET:-}" ]; then
      RESOURCE_REGISTRATION_IAM_CLIENT_SECRET=$(generate_aes_key 32)
      add_to_state_file "RESOURCE_REGISTRATION_IAM_CLIENT_SECRET" "$RESOURCE_REGISTRATION_IAM_CLIENT_SECRET"
      echo ""
      echo "❗  Generated credentials:"
      echo "RESOURCE_REGISTRATION_IAM_CLIENT_ID: $RESOURCE_REGISTRATION_IAM_CLIENT_ID"
      echo "RESOURCE_REGISTRATION_IAM_CLIENT_SECRET: $RESOURCE_REGISTRATION_IAM_CLIENT_SECRET"
      echo ""
  fi
fi

if [[ "$RESOURCE_REGISTRATION_ENABLE_OIDC" == "yes" ]]; then
    if [ -z "${RESOURCE_REGISTRATION_APISIX_SESSION_SECRET:-}" ]; then
    RESOURCE_REGISTRATION_APISIX_SESSION_SECRET=$(generate_aes_key 32)
    add_to_state_file "RESOURCE_REGISTRATION_APISIX_SESSION_SECRET" "$RESOURCE_REGISTRATION_APISIX_SESSION_SECRET"
    fi
fi


# Generate configuration files
gomplate  -f "registration-api/$TEMPLATE_PATH" -o "registration-api/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-api/$INGRESS_TEMPLATE_PATH" -o "registration-api/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/$TEMPLATE_PATH" -o "registration-harvester/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/$INGRESS_TEMPLATE_PATH" -o "registration-harvester/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/harvester-values/values-landsat-template.yaml" -o "registration-harvester/harvester-values/values-landsat.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/harvester-values/values-sentinel-template.yaml" -o "registration-harvester/harvester-values/values-sentinel.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/harvester-values/values-stac-template.yaml" -o "registration-harvester/harvester-values/values-stac.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

# eodata-server + STAC browser
gomplate  -f "registration-harvester/eodata-server-template.yaml" -o "registration-harvester/generated-eodata-server.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/stac-browser-template.yaml" -o "registration-harvester/generated-stac-browser.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

if [[ "$RESOURCE_REGISTRATION_ENABLE_OIDC" == "yes" || "$RESOURCE_REGISTRATION_PROTECTED_TARGETS" == "yes" ]]; then
    source ../common/prerequisite-utils.sh
    run_validation "check_crossplane_installed"

    gomplate -f "iam-template.yaml" -o "generated-iam.yaml"
fi

echo "Please proceed to apply the necessary Kubernetes secrets before deploying."
