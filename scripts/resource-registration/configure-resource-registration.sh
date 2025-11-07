# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Registration Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
ask "SHARED_STORAGECLASS" "Specify the Kubernetes storage class for SHARED data (ReadWriteMany)" "standard" is_non_empty
configure_cert

ask "FLOWABLE_ADMIN_USER" "Set what you'd like your Flowable admin username to be" "eoepca" is_non_empty
ask "FLOWABLE_ADMIN_PASSWORD" "Set what you'd like your Flowable admin password to be" "eoepca" is_non_empty

# Enable protected endpoints?
ask_yes_no "RESOURCE_REGISTRATION_PROTECTED_ENDPOINTS" "Do you want to enable protected endpoints for Resource Registration API?" "n"

# if protected endpoints are enabled, ask for IAM client ID and secret
if [[ "$RESOURCE_REGISTRATION_PROTECTED_ENDPOINTS" == "y" || "$RESOURCE_REGISTRATION_PROTECTED_ENDPOINTS" == "Y" ]]; then
  ask "RESOURCE_REGISTRATION_IAM_CLIENT_ID" "Enter the IAM Client ID for Resource Registration API" "registration-api" is_non_empty
  ask "RESOURCE_REGISTRATION_IAM_CLIENT_SECRET" "Enter the IAM Client Secret for Resource Registration API" "" is_non_empty
fi

# Generate configuration files
gomplate  -f "registration-api/$TEMPLATE_PATH" -o "registration-api/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-api/$INGRESS_TEMPLATE_PATH" -o "registration-api/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/$TEMPLATE_PATH" -o "registration-harvester/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/$INGRESS_TEMPLATE_PATH" -o "registration-harvester/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/harvester-values/values-landsat-template.yaml" -o "registration-harvester/harvester-values/values-landsat.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"


# eodata-server - Generate deployment yaml from template
gomplate  -f "registration-harvester/eodata-server-template.yaml" -o "registration-harvester/generated-eodata-server.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "Please proceed to apply the necessary Kubernetes secrets before deploying."
