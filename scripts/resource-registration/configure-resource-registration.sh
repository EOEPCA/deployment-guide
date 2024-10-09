# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Registration Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty

ask "FLOWABLE_ADMIN_USER" "Enter Flowable admin username" "eoepca" is_non_empty
ask "FLOWABLE_ADMIN_PASSWORD" "Enter Flowable admin password" "eoepca" is_non_empty

# Generate configuration files
envsubst <"registration-api/values-template.yaml" >"registration-api/generated-values.yaml"
envsubst <"registration-harvester/values-template.yaml" >"registration-harvester/generated-values.yaml"

echo "Please proceed to apply the necessary Kubernetes secrets before deploying."