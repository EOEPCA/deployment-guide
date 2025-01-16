#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Health Building Block..."

# Collect user inputs
ask "INTERNAL_CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for internal TLS certificates" "eoepca-ca-clusterissuer" is_non_empty
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
configure_cert

# Generate configuration files
envsubst <"values-template.yaml" >"generated-values.yaml"
envsubst <"sample-ingress-template.yaml" >"generated-ingress.yaml"

echo "You can now proceed to deploy the Resource Health BB using Helm."
