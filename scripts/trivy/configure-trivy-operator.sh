#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Configuring Trivy Operator..."

ask "TRIVY_SCAN_JOBS_CONCURRENCY" "Enter the number of Trivy scans that should run in parallerl" "10" is_non_empty

# Generate templated configuration files
echo "Generating configuration files..."

export KUBERNETES_VERSION=$(kubectl version -o json | jq -r '.serverVersion | "\(.major).\(.minor)"')

gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "Configuration complete!"
