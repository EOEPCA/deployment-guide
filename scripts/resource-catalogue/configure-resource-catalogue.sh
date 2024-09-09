#!/bin/bash

echo "Configuring the Resource Catalogue..."
source ../common/utils.sh

# Retrieve values
ask RESOURCE_CATALOGUE_NAMESPACE "Enter the namespace for the Resource Catalogue:" "default"
ask RESOURCE_CATALOGUE_INGRESS_ENABLED "Set ingress enabled to 'true' for direct access or 'false' if using identity gatekeeper:" "true"

# if its disabled, then skip the ingress extra config.
ask RESOURCE_CATALOGUE_INGRESS_HOST "Enter the public URL for the Resource Catalogue:" "resource-catalogue.example.com"
ask INGRESS_CLASS "Specify the ingress class for the Resource Catalogue:" "nginx"

ask RESOURCE_CATALOGUE_DB_ENABLED "Enable local database for the Resource Catalogue? (Set to 'false' if you are using an external DB)" "true"
ask DB_STORAGE_CLASS "Specify the Kubernetes storage class for database persistence:" "managed-nfs-storage-retain"
ask CLUSTER_ISSUER "Specify the cert-manager cluster issuer for TLS certificates:" "letsencrypt-prod"
ask PYCSW_URL "Set the PyCSW server URL, typically the same as the ingress host:" "$INGRESS_HOST"

# Generate values.yaml. 
# Can live inside of this own repo. So move this out.
cat >./generated-values.yaml <<EOF
global:
  namespace: ${RESOURCE_CATALOGUE_NAMESPACE}
ingress:
  enabled: ${RESOURCE_CATALOGUE_INGRESS_ENABLED}
  name: resource-catalogue
  host: ${RESOURCE_CATALOGUE_INGRESS_HOST}
  tls_host: ${RESOURCE_CATALOGUE_INGRESS_HOST}
  tls_secret_name: resource-catalogue-tls
  class: ${INGRESS_CLASS}
  className: ${INGRESS_CLASS}
  annotations:
    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}
db:
  volume_storage_type: ${DB_STORAGE_CLASS}
  config:
    enabled: ${RESOURCE_CATALOGUE_DB_ENABLED}
pycsw:
  config:
    server:
      url: https://${PYCSW_URL}
EOF

echo "Configuration file generated: ./generated-values.yaml"
echo "State file updated: $STATE_FILE"
