#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

check_pods_running "minio" "release=minio" 2

check_service_exists "minio" "minio-console"
check_service_exists "minio" "minio-svc"
check_service_exists "minio" "minio"

check_url_status_code "$HTTP_SCHEME://minio.$INGRESS_HOST" "403"
check_url_status_code "$HTTP_SCHEME://console-minio.$INGRESS_HOST" "200"

check_pvc_bound "minio" "export-minio-0"
check_pvc_bound "minio" "export-minio-1"

echo

# Ask user for confirmation to proceed
read -p "Do you want to proceed with MinIO functionality tests? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo
echo "Performing MinIO functionality tests..."

# Check if aws CLI is installed
if ! command -v aws &> /dev/null
then
    echo "aws CLI could not be found. Please install aws CLI to proceed."
    echo "Refer to https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html for installation instructions."
    exit 1
fi

# Configure aws CLI with creds from state
AWS_CLI_PROFILE="minio-validation-profile"
AWS_CONFIG_DIR="$(mktemp -d)"
export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
export AWS_DEFAULT_REGION="$S3_REGION"
mkdir -p "$AWS_CONFIG_DIR"

cat > "$AWS_CONFIG_DIR/config" <<EOF
[default]
region = $S3_REGION
output = json
EOF

cat > "$AWS_CONFIG_DIR/credentials" <<EOF
[default]
aws_access_key_id = $S3_ACCESS_KEY
aws_secret_access_key = $S3_SECRET_KEY
EOF

export AWS_CONFIG_FILE="$AWS_CONFIG_DIR/config"
export AWS_SHARED_CREDENTIALS_FILE="$AWS_CONFIG_DIR/credentials"
ENDPOINT_URL="$S3_ENDPOINT"

# Random name and date to avoid conflicts
BUCKET_NAME="validation-bucket-$(date +%s)-$RANDOM"

# Create a small text file
TEST_FILE="minio-validation-testfile.txt"
echo "This is a test file for MinIO validation." > "$TEST_FILE"

# Create the bucket
echo "Creating bucket: $BUCKET_NAME"
aws --endpoint-url="$ENDPOINT_URL" s3api create-bucket --bucket "$BUCKET_NAME" --region "$S3_REGION"
if [ $? -ne 0 ]; then
    echo "Failed to create bucket."
    exit 1
fi

# Upload the test file
echo "Uploading test file to bucket: $BUCKET_NAME"
aws --endpoint-url="$ENDPOINT_URL" s3 cp "$TEST_FILE" "s3://$BUCKET_NAME/"
if [ $? -ne 0 ]; then
    echo "Failed to upload file."
    exit 1
fi

# List objects in the bucket
echo "Listing objects in bucket: $BUCKET_NAME"
aws --endpoint-url="$ENDPOINT_URL" s3 ls "s3://$BUCKET_NAME/"
if [ $? -ne 0 ]; then
    echo "Failed to list objects."
    exit 1
fi

# Delete the test file from the bucket
echo "Deleting test file from bucket: $BUCKET_NAME"
aws --endpoint-url="$ENDPOINT_URL" s3 rm "s3://$BUCKET_NAME/$TEST_FILE"
if [ $? -ne 0 ]; then
    echo "Failed to delete test file."
    exit 1
fi

# Delete the bucket
echo "Deleting bucket: $BUCKET_NAME"
aws --endpoint-url="$ENDPOINT_URL" s3api delete-bucket --bucket "$BUCKET_NAME" --region "$S3_REGION"
if [ $? -ne 0 ]; then
    echo "Failed to delete bucket."
    exit 1
fi

# Clean up
rm -f "$TEST_FILE"
rm -rf "$AWS_CONFIG_DIR"

echo "MinIO functionality tests completed successfully."
