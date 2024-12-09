#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."

kubectl create namespace iam --dry-run=client -o yaml | kubectl apply -f -

if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ]; then
  echo "❌ KEYCLOAK_ADMIN_PASSWORD is not set. Please run configure-iam.sh first."
  exit 1
fi

if [ -z "$KEYCLOAK_POSTGRES_PASSWORD" ]; then
  echo "❌ KEYCLOAK_POSTGRES_PASSWORD is not set. Please run configure-iam.sh first."
  exit 1
fi

if [ -z "$OPA_CLIENT_SECRET" ]; then
  echo "❌ OPA_CLIENT_SECRET is not set. Please run configure-iam.sh first."
  exit 1
fi

# Create secret for Keycloak admin credentials
kubectl create secret generic keycloak-admin \
  --from-literal=username="$KEYCLOAK_ADMIN_USER" \
  --from-literal=password="$KEYCLOAK_ADMIN_PASSWORD" \
  --namespace iam --dry-run=client -o yaml | kubectl apply -f -

# Create secret for Keycloak PostgreSQL credentials
kubectl create secret generic kc-postgres \
  --from-literal=password="$KEYCLOAK_POSTGRES_PASSWORD" \
  --from-literal=postgres-password="$KEYCLOAK_POSTGRES_PASSWORD" \
  --namespace iam --dry-run=client -o yaml | kubectl apply -f -

# Create secret for OPA client
kubectl create secret generic opa-keycloak-client \
  --from-literal=client_id=opa \
  --from-literal=client_secret="$OPA_CLIENT_SECRET" \
  --namespace iam --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets applied."