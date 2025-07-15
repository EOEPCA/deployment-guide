#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Data Access Building Block..."

# Collect user inputs
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
configure_cert

ask "EXTERNAL_POSTGRES" "Do you want to use an eternal Postgres?" "false" is_non_empty
if $EXTERNAL_POSTGRES; then
  ask "EXTERNAL_POSTGRES_HOST" "External Postgres host" "eoapi-db.$INGRESS_HOST" is_non_empty
  ask "EXTERNAL_POSTGRES_PORT" "External Postgres port" "5432" is_non_empty
  ask "EXTERNAL_POSTGRES_DBNAME" "External Postgres database name" "eoapi" is_non_empty
  ask "EXTERNAL_POSTGRES_USERNAME" "External Postgres database username" "eoapi" is_non_empty
  ask "EXTERNAL_POSTGRES_PASSWORD" "External Postgres database password" "eoapi" is_non_empty
fi

gomplate  -f "eoapi/$TEMPLATE_PATH" -o "eoapi/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "postgres/$TEMPLATE_PATH" -o "postgres/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "eoapi-support/$TEMPLATE_PATH" -o "eoapi-support/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "stac-manager/$TEMPLATE_PATH" -o "stac-manager/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
gomplate  -f "eoapi-maps-plugin/$TEMPLATE_PATH" -o "eoapi-maps-plugin/$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

if [ "$INGRESS_CLASS" == "apisix" ]; then
    gomplate  -f "eoapi/$INGRESS_TEMPLATE_PATH" -o "eoapi/$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi
