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

read -p "Do you want to proceed with MinIO functionality tests? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo
echo "Performing MinIO functionality tests with s3cmd..."

# Check if s3cmd is installed
if ! command -v s3cmd &>/dev/null; then
    echo "s3cmd could not be found. Please install s3cmd to proceed."
    echo "Refer to https://s3tools.org/download for installation instructions."
    exit 1
fi

# These must already be set in your ~/.eoepca/state, or set them here:
# export S3_ACCESS_KEY="..."
# export S3_SECRET_KEY="..."
# export S3_ENDPOINT="https://minio.${INGRESS_HOST}"
# export S3_REGION="eu-west-2"

# Random name and date to avoid conflicts
BUCKET_NAME="validation-bucket-$(date +%s)-$RANDOM"
TEST_FILE="minio-validation-testfile.txt"

# We will create a small text file as a test object
echo "This is a test file for MinIO validation (s3cmd version)." >"$TEST_FILE"

echo
echo "Creating bucket: $BUCKET_NAME"
s3cmd mb "s3://$BUCKET_NAME" \
    --host "minio.${INGRESS_HOST}" \
    --host-bucket "minio.${INGRESS_HOST}" \
    --access_key "$S3_ACCESS_KEY" \
    --secret_key "$S3_SECRET_KEY" \
    --region="$S3_REGION"
if [ $? -ne 0 ]; then
    echo "Failed to create bucket."
    rm -f "$TEST_FILE"
    exit 1
fi

echo
echo "Uploading test file to bucket: $BUCKET_NAME"
s3cmd put "$TEST_FILE" "s3://$BUCKET_NAME/" \
    --host "minio.${INGRESS_HOST}" \
    --host-bucket "minio.${INGRESS_HOST}" \
    --access_key "$S3_ACCESS_KEY" \
    --secret_key "$S3_SECRET_KEY" \
    --region="$S3_REGION"
if [ $? -ne 0 ]; then
    echo "Failed to upload file."
    rm -f "$TEST_FILE"
    exit 1
fi

echo
echo "Listing objects in bucket: $BUCKET_NAME"
s3cmd ls "s3://$BUCKET_NAME/" \
    --host "minio.${INGRESS_HOST}" \
    --host-bucket "minio.${INGRESS_HOST}" \
    --access_key "$S3_ACCESS_KEY" \
    --secret_key "$S3_SECRET_KEY" \
    --region="$S3_REGION"
if [ $? -ne 0 ]; then
    echo "Failed to list objects."
    rm -f "$TEST_FILE"
    exit 1
fi

echo
echo "Deleting test file from bucket: $BUCKET_NAME"
s3cmd del "s3://$BUCKET_NAME/$TEST_FILE" \
    --host "minio.${INGRESS_HOST}" \
    --host-bucket "minio.${INGRESS_HOST}" \
    --access_key "$S3_ACCESS_KEY" \
    --secret_key "$S3_SECRET_KEY" \
    --region="$S3_REGION"
if [ $? -ne 0 ]; then
    echo "Failed to delete test file."
    rm -f "$TEST_FILE"
    exit 1
fi

echo
echo "Deleting bucket: $BUCKET_NAME"
s3cmd rb "s3://$BUCKET_NAME" \
    --host "minio.${INGRESS_HOST}" \
    --host-bucket "minio.${INGRESS_HOST}" \
    --access_key "$S3_ACCESS_KEY" \
    --secret_key "$S3_SECRET_KEY" \
    --region="$S3_REGION"
if [ $? -ne 0 ]; then
    echo "Failed to delete bucket."
    rm -f "$TEST_FILE"
    exit 1
fi

rm "$TEST_FILE"

echo
echo "MinIO functionality tests (s3cmd) completed successfully."
