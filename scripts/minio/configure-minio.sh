#!/bin/bash

echo "Configuring Minio..."
source ../common/utils.sh

# Collect user inputs
ask "INGRESS_HOST" "Enter the base ingress host" "example.com" is_valid_domain
ask "CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for TLS certificates" "letsencrypt-prod" is_non_empty
ask "DB_STORAGE_CLASS" "Specify the Kubernetes storage class for database persistence" "managed-nfs-storage-retain" is_non_empty

envsubst <"api/$TEMPLATE_PATH" >"api/$OUTPUT_PATH"
envsubst <"server/$TEMPLATE_PATH" >"server/$OUTPUT_PATH"

export MINIO_USER=user
export MINIO_PASSWORD=$(generate_aes_key 32)

add_to_state_file "MINIO_USER" $MINIO_USER
add_to_state_file "MINIO_PASSWORD" $MINIO_PASSWORD

kubectl create secret generic minio-auth \
    --from-literal=rootUser="$MINIO_USER" \
    --from-literal=rootPassword="$MINIO_PASSWORD"

echo "✅ Configuration file generated: $OUTPUT_PATH"

echo ""
echo "🔐 IMPORTANT: The following secrets have been generated or used for your deployment:"
echo "Minio User: $MINIO_USER"
echo "Minio Password: $MINIO_PASSWORD"
