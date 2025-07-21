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

# Use the Workspace API
ask "USE_WORKSPACE_API" "Do you want to use the Workspace API to manage your execution context? IMPORTANT: Only set this to true if you are using the Workspace API" "false" is_boolean

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

# OIDC
ask "OIDC_OAPIP_ENABLED" "Do you want to enable OIDC for the OAPIP?" "true" is_boolean


if [ "$OIDC_OAPIP_ENABLED" == "true" ]; then

    ask "OAPIP_CLIENT_ID" "Enter the Client ID for the OAPIP" "oapip-engine" is_non_empty

    if [ -z "$OAPIP_CLIENT_SECRET" ]; then
        OAPIP_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "OAPIP_CLIENT_SECRET" "$OAPIP_CLIENT_SECRET"
    fi
    echo ""
    echo "❗  Generated client secret for the OAPIP."
    echo "   Please store this securely: $OAPIP_CLIENT_SECRET"
    echo ""

    if [ -z "$KEYCLOAK_HOST" ]; then
        ask "KEYCLOAK_HOST" "Enter the Keycloak full host domain excluding https (e.g., auth.example.com)" "auth.${INGRESS_HOST}" is_valid_domain
    fi

    if [ -z "$REALM" ]; then
        ask "REALM" "Enter the Keycloak realm" "eoepca" is_non_empty
    fi

    add_to_state_file "OAPIP_HOST" "${HTTP_SCHEME}://zoo.${INGRESS_HOST}"

    if [ "$INGRESS_CLASS" == "apisix" ]; then
        add_to_state_file "OAPIP_INGRESS_ENABLED" "false"
        gomplate -f "$INGRESS_TEMPLATE_PATH" -o "$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    else
        add_to_state_file "OAPIP_INGRESS_ENABLED" "true"
    fi


else

    add_to_state_file "OAPIP_INGRESS_ENABLED" "true"
    add_to_state_file "OAPIP_HOST" "${HTTP_SCHEME}://zoo.${INGRESS_HOST}"

fi

# Processing engine
is_valid_engine() {
    [[ "$1" == "calrissian" || "$1" == "toil" || "$1" == "argo" ]]
}
ask "OAPIP_EXECUTION_ENGINE" "Select your execution engine. Supported engines are calrissian, toil and argo." "calrissian" is_valid_engine

if [[ "$OAPIP_EXECUTION_ENGINE" == "toil" ]]; then
 ask "OAPIP_TOIL_WES_URL" "Insert the HPC Toil WES service endpoint" "https://toil.hpc.host/ga4gh/wes/v1/" is_non_empty
 ask "OAPIP_TOIL_WES_USER" "Insert the HPC Toil WES username" "test" is_non_empty
 ask "OAPIP_TOIL_WES_PASSWORD" "Insert the HPT Toil WES password (hashed)" '$2y$12$ci.4U63YX83CwkyUrjqxAucnmi2xXOIlEF6T/KdP9824f1Rf1iyNG' is_non_empty
elif [[ "$OAPIP_EXECUTION_ENGINE" == "calrissian" ]]; then
 ask "NODE_SELECTOR_KEY" "Specify the selector to determine which nodes will run processing workflows" "kubernetes.io/os" is_non_empty
 ask "NODE_SELECTOR_VALUE" "Specify the value of the node selector" "linux" is_non_empty
fi

gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
