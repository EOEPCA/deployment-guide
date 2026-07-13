#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."

kubectl create namespace iam --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace iam-management --dry-run=client -o yaml | kubectl apply -f -

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

if [ -z "${IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET:-}" ]; then
  echo "❌ IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET is not set. Please run configure-iam.sh first."
  exit 1
fi

if [ -z "${IAM_OPA_SESSION_SECRET:-}" ]; then
  echo "❌ IAM_OPA_SESSION_SECRET is not set. Please run configure-iam.sh first."
  exit 1
fi

if [ -z "${KEYCLOAK_TEST_PASSWORD:-}" ]; then
  echo "❌ KEYCLOAK_TEST_PASSWORD is not set. Please run configure-iam.sh first."
  exit 1
fi

# Create secret for Keycloak admin credentials
kubectl create secret generic keycloak-admin \
  --from-literal=username="${KEYCLOAK_ADMIN_USER:-admin}" \
  --from-literal=password="$KEYCLOAK_ADMIN_PASSWORD" \
  --from-literal=admin-password="$KEYCLOAK_ADMIN_PASSWORD" \
  --namespace iam --dry-run=client -o yaml | kubectl apply -f -

# Create secret for Keycloak PostgreSQL credentials
kubectl create secret generic postgresql \
  --from-literal=username="keycloak" \
  --from-literal=password="$KEYCLOAK_POSTGRES_PASSWORD" \
  --from-literal=postgres-password="$KEYCLOAK_POSTGRES_PASSWORD" \
  --namespace iam --dry-run=client -o yaml | kubectl apply -f -

KEYCLOAK_PROVIDER_CREDENTIALS=$(cat <<EOF
{
  "client_id": "crossplane-keycloak-provider",
  "client_secret": "$IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET",
  "url": "${HTTP_SCHEME}://${KEYCLOAK_HOST}",
  "base_path": "",
  "realm": "$REALM"
}
EOF
)

for namespace in iam iam-management; do
  kubectl create secret generic keycloak-provider \
    --from-literal=client_id="crossplane-keycloak-provider" \
    --from-literal=client_secret="$IAM_KEYCLOAK_PROVIDER_CLIENT_SECRET" \
    --from-literal=url="${HTTP_SCHEME}://${KEYCLOAK_HOST}" \
    --from-literal=base_path="" \
    --from-literal=realm="$REALM" \
    --from-literal=credentials="$KEYCLOAK_PROVIDER_CREDENTIALS" \
    --namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
done

for namespace in iam iam-management; do
  kubectl create secret generic opa-route \
    --from-literal=client_id="${OPA_CLIENT_ID:-opa}" \
    --from-literal=client_secret="$OPA_CLIENT_SECRET" \
    --from-literal=session.secret="$IAM_OPA_SESSION_SECRET" \
    --namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl create secret generic iam-keycloak \
  --from-literal=test-user-password="$KEYCLOAK_TEST_PASSWORD" \
  --namespace iam --dry-run=client -o yaml | kubectl apply -f -

# Consumed by the Crossplane User CR (eoepca-user-template.yaml) that creates
# the eoepcauser test user once IAM and Crossplane are up.
kubectl create secret generic eoepca-user \
  --from-literal=eoepcauser-password="$KEYCLOAK_TEST_PASSWORD" \
  --namespace iam-management --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets applied."
