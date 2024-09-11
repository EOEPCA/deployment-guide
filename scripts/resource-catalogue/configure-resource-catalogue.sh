#!/bin/bash

echo "Configuring the Resource Catalogue..."

# Load utility functions
source ../common/utils.sh

# Template paths
template_path="./values-template.yaml"
intermediate_output_path="./intermediate-values.yaml"
final_output_path="./generated-values.yaml"

# Generic user inputs
ask INGRESS_HOST "Enter the base ingress host:" "example.com"
ask CLUSTER_ISSUER "Specify the cert-manager cluster issuer for TLS certificates:" "letsencrypt-prod"
ask DB_STORAGE_CLASS "Specify the Kubernetes storage class for database persistence:" "managed-nfs-storage-retain"

# Collection user inputs
ask RESOURCE_CATALOGUE_NAMESPACE "Enter the namespace for the Resource Catalogue:" "default"
ask RESOURCE_CATALOGUE_INGRESS_ENABLED "Set ingress enabled to 'true' for direct access or 'false' if using identity gatekeeper:" "true"
ask RESOURCE_CATALOGUE_DB_ENABLED "Enable local database for the Resource Catalogue? (Set to 'false' if you are using an external DB)" "true"
ask PYCSW_URL "Set the PyCSW server URL, typically the same as the ingress host:" "$INGRESS_HOST"

# Apply replacements
cp "$template_path" "$intermediate_output_path"
replace_placeholder "$intermediate_output_path" "$final_output_path" "INGRESS_HOST" "$INGRESS_HOST"
replace_placeholder "$final_output_path" "$final_output_path" "CLUSTER_ISSUER" "$CLUSTER_ISSUER"
replace_placeholder "$final_output_path" "$final_output_path" "DB_STORAGE_CLASS" "$DB_STORAGE_CLASS"
replace_placeholder "$final_output_path" "$final_output_path" "RESOURCE_CATALOGUE_NAMESPACE" "$RESOURCE_CATALOGUE_NAMESPACE"
replace_placeholder "$final_output_path" "$final_output_path" "RESOURCE_CATALOGUE_INGRESS_ENABLED" "$RESOURCE_CATALOGUE_INGRESS_ENABLED"
replace_placeholder "$final_output_path" "$final_output_path" "RESOURCE_CATALOGUE_DB_ENABLED" "$RESOURCE_CATALOGUE_DB_ENABLED"
replace_placeholder "$final_output_path" "$final_output_path" "PYCSW_URL" "$PYCSW_URL"
rm "$intermediate_output_path"

echo "Configuration file generated: $final_output_path"
