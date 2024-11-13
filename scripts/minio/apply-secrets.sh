# Load utility functions
source ../common/utils.sh

echo "Access the MinIO Console to create your access key at https://console-minio.$INGRESS_HOST/access-keys/new-account"
echo "Your username is 'user' and the password is the one that was generated and outputted earlier, alteratively check the ~/.eoepca/state file for the password"

ask "S3_ACCESS_KEY" "Enter the S3 Access Key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the S3 Secret Key" "" is_non_empty

kubectl create secret generic minio-auth \
    --from-literal=rootUser="$MINIO_USER" \
    --from-literal=rootPassword="$MINIO_PASSWORD" \
    --namespace=minio

echo "Successfully saved Minio variables to state"
