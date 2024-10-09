#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh

kubectl create namespace resource-health --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace resource-health-opensearch --dry-run=client -o yaml | kubectl apply -f -

echo "Applying Kubernetes secrets and certificates..."

# Create Certificates using Cert Manager
kubectl apply -f certificates/opensearch-tls-certificate.yaml
kubectl apply -f certificates/opensearch-dashboards-tls-certificate.yaml
kubectl apply -f certificates/otel-collector-certificate.yaml
kubectl apply -f certificates/otel-collector-client-certificate.yaml
kubectl apply -f certificates/opensearch-admin-certificate.yaml
kubectl apply -f certificates/opensearch-dashboards-client-certificate.yaml

# Wait for certificates to be issued
echo "Waiting for certificates to be issued..."
kubectl wait --for=condition=Ready certificate --all -n resource-health-opensearch --timeout=180s

# Create secrets for Resource Health BB
kubectl create secret generic resource-health-iam-client-credentials \
  --from-literal=client_id="$KEYCLOAK_CLIENT_ID" \
  --from-literal=client_secret="$KEYCLOAK_CLIENT_SECRET" \
  --namespace resource-health

# Create secrets for OpenSearch
kubectl create secret generic sensmetry-user-secret \
  --from-literal=username="$SENSMETRY_USERNAME" \
  --from-literal=password="$SENSMETRY_PASSWORD" \
  --namespace resource-health

# Also create the secret in the resource-health-opensearch namespace
kubectl create secret generic sensmetry-user-secret \
  --from-literal=username="$SENSMETRY_USERNAME" \
  --from-literal=password="$SENSMETRY_PASSWORD" \
  --namespace resource-health-opensearch

echo "✅ Secrets and certificates applied."