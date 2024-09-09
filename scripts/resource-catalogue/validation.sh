#!/bin/bash

echo "Starting validation for the Resource Catalogue deployment..."
source ../common/utils.sh

# Check if state file exists and source it
if [ -f ~/.eoepca/state ]; then
  source ~/.eoepca/state
else
  echo "State file not found at ~/.eoepca/state"
  exit 1
fi

# Ask for namespace if it's not set
if [ -z "${RESOURCE_CATALOGUE_NAMESPACE}" ]; then
  ask RESOURCE_CATALOGUE_NAMESPACE "Enter the namespace for the Resource Catalogue:" "default" "$STATE_FILE"
fi

echo "Starting validation for the Resource Catalogue deployment in the '${RESOURCE_CATALOGUE_NAMESPACE}' namespace..."

# Check the pods
check_pods resource-catalogue

# TODO: Add StatefulSet check

# Check services
echo "Checking services..."
check_resource service resource-catalogue-service $RESOURCE_CATALOGUE_NAMESPACE
check_resource service resource-catalogue-db $RESOURCE_CATALOGUE_NAMESPACE

# Check ingress
echo "Checking ingress..."
check_resource ingress resource-catalogue $RESOURCE_CATALOGUE_NAMESPACE

# Check PVCs
echo "Checking persistent volume claims (PVCs)..."
PVC_STATUS=$(kubectl get pvc db-data-resource-catalogue-db-0 -n $RESOURCE_CATALOGUE_NAMESPACE --no-headers | awk '{print $2}')

if [ "$PVC_STATUS" == "Bound" ]; then
  echo "✅ PVC db-data-resource-catalogue-db-0 is bound."
else
  echo "❌ PVC db-data-resource-catalogue-db-0 is not bound."
fi

echo "All checks completed successfully!"
