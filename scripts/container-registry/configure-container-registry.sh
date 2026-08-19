#!/bin/bash

source ../common/utils.sh
echo "Configuring the Container Registry..."

export HARBOR_ADMIN_PASSWORD=$(generate_password)
export HARBOR_URL="$HTTP_SCHEME://harbor.$INGRESS_HOST"

add_to_state_file "HARBOR_ADMIN_PASSWORD" $HARBOR_ADMIN_PASSWORD
add_to_state_file "HARBOR_URL" $HARBOR_URL

gomplate  -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

echo "✅ Configuration file generated: $OUTPUT_PATH"

echo ""
echo "🔐 IMPORTANT: The following passwords have been generated for your deployment:"
echo "Harbor admin password: $HARBOR_ADMIN_PASSWORD"

