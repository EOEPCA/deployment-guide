#!/bin/bash

# Load utility functions and state file
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."

kubectl create namespace processing

kubectl create secret generic oapip-engine-client \
  --from-literal=client_id="oapip-engine" \
  --from-literal=client_secret="$OAPIP_CLIENT_SECRET" \
  --namespace processing

echo "✅ Secrets applied."
