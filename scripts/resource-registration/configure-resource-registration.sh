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
envsubst <"registration-api/values-template.yaml" >"registration-api/generated-values.yaml"
envsubst <"registration-api/$INGRESS_TEMPLATE_PATH" >"registration-api/$INGRESS_OUTPUT_PATH"
envsubst <"registration-harvester/values-template.yaml" >"registration-harvester/generated-values.yaml"
envsubst <"registration-harvester/$INGRESS_TEMPLATE_PATH" >"registration-harvester/$INGRESS_OUTPUT_PATH"

echo "Please proceed to apply the necessary Kubernetes secrets before deploying."
