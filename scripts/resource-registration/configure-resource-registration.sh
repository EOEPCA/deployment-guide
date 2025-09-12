# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Registration Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

ask "FLOWABLE_ADMIN_USER" "Set what you'd like your Flowable admin username to be" "eoepca" is_non_empty
ask "FLOWABLE_ADMIN_PASSWORD" "Set what you'd like your Flowable admin password to be" "eoepca" is_non_empty

# Generate configuration files
gomplate  -f "registration-api/$TEMPLATE_PATH" -o "registration-api/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-api/$INGRESS_TEMPLATE_PATH" -o "registration-api/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/$TEMPLATE_PATH" -o "registration-harvester/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "registration-harvester/$INGRESS_TEMPLATE_PATH" -o "registration-harvester/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

# eodata-server - Generate deployment yaml from template
gomplate  -f "registration-harvester/eodata-server-template.yaml" -o "registration-harvester/generated-eodata-server.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "Please proceed to apply the necessary Kubernetes secrets before deploying."
