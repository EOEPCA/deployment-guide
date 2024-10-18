#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Resource Health Building Block..."

# Collect user inputs
ask "INTERNAL_CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for internal TLS certificates" "eoepca-ca-clusterissuer" is_non_empty

# Generate configuration files
envsubst <"values-template.yaml" >"generated-values.yaml"

echo "You can now proceed to deploy the Resource Health BB using Helm."