#!/bin/bash
source ../../common/utils.sh

NAMESPACE="openeo"

echo "Applying Kubernetes secrets for OpenEO ArgoWorkflows..."

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# The openeo-argo chart sets postgresql.auth.existingSecret=openeo-postgresql by
# default - the bitnami postgresql subchart will not create its own password
# and expects this Secret (key "postgres-password") to already exist.
if [ -z "${OPENEO_ARGO_POSTGRES_PASSWORD:-}" ]; then
    OPENEO_ARGO_POSTGRES_PASSWORD="$(generate_password)"
    add_to_state_file "OPENEO_ARGO_POSTGRES_PASSWORD" "$OPENEO_ARGO_POSTGRES_PASSWORD"
fi

kubectl create secret generic openeo-postgresql \
    --from-literal=postgres-password="$OPENEO_ARGO_POSTGRES_PASSWORD" \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ OpenEO ArgoWorkflows secrets applied."
