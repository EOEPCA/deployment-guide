# Load utility functions
source ../common/utils.sh

ask "S3_ACCESS_KEY" "Enter the S3 Access Key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the S3 Secret Key" "" is_non_empty

echo "Successfully saved Minio variables to state"
