#!/bin/bash

# Load utility functions
source ../../common/utils.sh

echo "Configuring the Processing Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain for ingress hosts (e.g., example.com)" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

# Stage-out S3 configuration
ask "S3_ENDPOINT" "Enter the Stage-Out S3 Endpoint URL (e.g., ${HTTP_SCHEME}://minio.$INGRESS_HOST)" "${HTTP_SCHEME}://minio.$INGRESS_HOST" is_valid_domain
ask "S3_ACCESS_KEY" "Enter the Stage-Out S3 Access Key" "" is_non_empty
ask "S3_SECRET_KEY" "Enter the Stage-Out S3 Secret Key" "" is_non_empty
ask "S3_REGION" "Enter the Stage-Out S3 Region" "RegionOne" is_non_empty

# Stage-in S3 configuration
ask "DIFFERENT_STAGE_IN" "Will your outputs be stored in a different S3 store? (yes/no)" "no" is_non_empty
if [ "$DIFFERENT_STAGE_IN" = "yes" ]; then
    ask "STAGEIN_S3_ENDPOINT" "Enter the Stage-In S3 Endpoint URL (e.g., minio.$INGRESS_HOST)" "minio.$INGRESS_HOST" is_valid_domain
    ask "STAGEIN_S3_ACCESS_KEY" "Enter the Stage-In S3 Access Key" "" is_non_empty
    ask "STAGEIN_S3_SECRET_KEY" "Enter the Stage-In S3 Secret Key" "" is_non_empty
    ask "STAGEIN_S3_REGION" "Enter the Stage-In S3 Region" "eu-west-2" is_non_empty
fi

if [ "$DIFFERENT_STAGE_IN" = "no" ]; then
    add_to_state_file "STAGEIN_S3_ENDPOINT" $S3_ENDPOINT
    add_to_state_file "STAGEIN_S3_ACCESS_KEY" $S3_ACCESS_KEY
    add_to_state_file "STAGEIN_S3_SECRET_KEY" $S3_SECRET_KEY
    add_to_state_file "STAGEIN_S3_REGION" $S3_REGION
fi

if [ -z "$OAPIP_CLIENT_SECRET" ]; then
    OAPIP_CLIENT_SECRET=$(generate_aes_key 32)
    add_to_state_file "OAPIP_CLIENT_SECRET" "$OAPIP_CLIENT_SECRET"
fi

envsubst < "$TEMPLATE_PATH" > "$OUTPUT_PATH"
envsubst <"ingress-template.yaml" >"generated-ingress.yaml"

if [ "$USE_CERT_MANAGER" == "no" ]; then
    echo ""
    echo "📄 Since you're not using cert-manager, please create the following TLS secrets manually before deploying:"
    echo "- zoo-tls"
fi
