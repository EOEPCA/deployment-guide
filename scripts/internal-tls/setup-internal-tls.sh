#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Setting up internal TLS..."

# Install Cert-Manager
if ! kubectl rollout status deployment cert-manager -n cert-manager --timeout=120s >/dev/null 2>&1; then
  echo "Installing Cert-Manager..."
  helm repo add jetstack https://charts.jetstack.io &&
    helm repo update jetstack &&
    helm upgrade -i cert-manager jetstack/cert-manager \
      --namespace cert-manager --create-namespace \
      --version v1.16.1 \
      --set crds.enabled=true
else
  echo "Cert-Manager already installed"
fi

# Wait for Cert-Manager to be ready
echo "Waiting for Cert-Manager to be ready..."
kubectl rollout status deployment cert-manager -n cert-manager --timeout=120s

# Apply manifests
kubectl apply -f certificates/cert-manager-ss-issuer.yaml
kubectl apply -f certificates/cert-manager-ca-cert.yaml
kubectl apply -f certificates/cert-manager-ca-issuer.yaml

# Wait for the CA certificate to be ready
echo "Waiting for CA certificate to be ready..."
kubectl wait --for=condition=Ready certificate eoepca-ca -n cert-manager --timeout=180s

add_to_state_file "INTERNAL_TLS_ENABLED" "true"

echo "✅ Internal TLS setup completed successfully."
