#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."

# Create secrets for Flowable
kubectl create secret generic flowable-admin-credentials \
  --from-literal=FLOWABLE_ADMIN_USER="$FLOWABLE_ADMIN_USER" \
  --from-literal=FLOWABLE_ADMIN_PASSWORD="$FLOWABLE_ADMIN_PASSWORD" \
  --namespace rm

echo "✅ Secrets applied."