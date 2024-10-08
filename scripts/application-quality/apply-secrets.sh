#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh

# Create Kubernetes secret
kubectl create secret generic application-quality-secret \
  --from-literal=secret-key="$APPLICATION_QUALITY_SECRET_KEY" \
  --namespace application-quality
