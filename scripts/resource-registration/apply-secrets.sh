#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."
kubectl create namespace resource-registration --dry-run=client -o yaml | kubectl apply -f -

# Create secrets for Flowable
kubectl create secret generic flowable-admin-credentials \
  --from-literal=FLOWABLE_ADMIN_USER="$FLOWABLE_ADMIN_USER" \
  --from-literal=FLOWABLE_ADMIN_PASSWORD="$FLOWABLE_ADMIN_PASSWORD" \
  --namespace resource-registration \
  --dry-run=client -o yaml | kubectl apply -f -

# Create secrets for registration harvester secret
kubectl create secret generic registration-harvester-secret \
  --from-literal=FLOWABLE_USER="$FLOWABLE_ADMIN_USER" \
  --from-literal=FLOWABLE_PASSWORD="$FLOWABLE_ADMIN_PASSWORD" \
  --namespace resource-registration \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets applied."
