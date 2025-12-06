#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Notification & Automation Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain

configure_cert

# Generate configuration files
gomplate -f "knative-template.yaml" -o "generated-knative.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate -f "apisix-route-template.yaml" -o "generated-apisix-route.yaml" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ Configuration files generated successfully"