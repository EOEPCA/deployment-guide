#!/bin/bash

# Load utility functions
source ../common/utils.sh

# Template paths
template_path="./values-template.yaml"
intermediate_output_path="./intermediate-values.yaml"
final_output_path="./generated-values.yaml"

# Collect user inputs
ask CLUSTER_ISSUER "Enter the namespace for the CLUSTER_ISSUER:" "letsencrypt-prod"
ask INGRESS_HOST "Enter the base ingress host:" "example.com"
ask DB_STORAGE_CLASS "Enter the storage class for the database:" "managed-nfs-storage-retain"
ask AWS_ENDPOINT_URL_S3 "Enter the AWS S3 endpoint URL:" "minio.${INGRESS_HOST}"

# Apply replacements
cp "$template_path" "$intermediate_output_path"

replace_placeholder "$intermediate_output_path" "$final_output_path" "CLUSTER_ISSUER" "$CLUSTER_ISSUER"
replace_placeholder "$final_output_path" "$final_output_path" "INGRESS_HOST" "$INGRESS_HOST"
replace_placeholder "$final_output_path" "$final_output_path" "DB_STORAGE_CLASS" "$DB_STORAGE_CLASS"
replace_placeholder "$final_output_path" "$final_output_path" "AWS_ENDPOINT_URL_S3" "$AWS_ENDPOINT_URL_S3"

rm "$intermediate_output_path"
echo "Configuration file generated: $final_output_path"
