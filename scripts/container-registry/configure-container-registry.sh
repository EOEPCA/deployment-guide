#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Container Registry..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
configure_cert

export HARBOR_ADMIN_PASSWORD=$(generate_password)
export HARBOR_URL="$HTTP_SCHEME://harbor.$INGRESS_HOST"

add_to_state_file "HARBOR_ADMIN_PASSWORD" $HARBOR_ADMIN_PASSWORD
add_to_state_file "HARBOR_URL" $HARBOR_URL

gomplate  -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ Configuration file generated: $OUTPUT_PATH"

# Notify the user to store the generated passwords
echo ""
echo "🔐 IMPORTANT: The following passwords have been generated for your deployment:"
echo "Harbor admin password: $HARBOR_ADMIN_PASSWORD"

