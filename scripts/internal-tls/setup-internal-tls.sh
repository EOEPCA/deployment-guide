#!/bin/bash

# Load utility functions
source ../common/utils.sh

echo "Setting up internal TLS..."

# Install Cert-Manager
echo "Installing Cert-Manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update

kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.12.2 \
  --set installCRDs=true

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

echo "✅ Internal TLS setup completed successfully."