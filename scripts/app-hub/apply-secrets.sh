#!/bin/bash

source ../common/utils.sh
source "$HOME/.eoepca/state"

NAMESPACE="app-hub"

echo "Applying Kubernetes secrets for Application Hub..."

for required_var in APPHUB_JUPYTERHUB_CRYPT_KEY APPHUB_CLIENT_ID APPHUB_CLIENT_SECRET; do
  if [ -z "${!required_var:-}" ]; then
    echo "ERROR: ${required_var} is not set. Run configure-app-hub.sh before applying secrets."
    exit 1
  fi
done

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic application-hub \
  --from-literal=JUPYTERHUB_CRYPT_KEY="${APPHUB_JUPYTERHUB_CRYPT_KEY}" \
  --from-literal=OAUTH_CLIENT_ID="${APPHUB_CLIENT_ID}" \
  --from-literal=OAUTH_CLIENT_SECRET="${APPHUB_CLIENT_SECRET}" \
  --namespace "${NAMESPACE}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Application Hub secrets applied."
