#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source ../cluster/functions
configureAction "$1"
initIpDefaults

domain="${2:-${default_domain}}"

SECRET_NAME="django-secrets"
NAMESPACE="demo"

values() {
  cat - <<EOF
domain: ${domain}
authHost: auth
configmap:
  oidc_verify_ssl: "false"
  user_prefix: eoepca-user
# image:
#   tag: latest
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall django-portal
else
  # helm chart
  values | helm ${ACTION_HELM} django-portal django-portal -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace "${NAMESPACE}" --create-namespace \
    --version 1.0.0
  
  # secret
  if [ -f client.yaml ]; then
    django_secret="$(../bin/token-urlsafe)"
    client_id="$(cat client.yaml | grep client-id | cut -d\  -f2)"
    client_secret=$(cat client.yaml | grep client-secret | cut -d\  -f2)
    echo "Creating secret ${SECRET_NAME} in namespace ${NAMESPACE}..."
    kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
      --from-literal=DJANGO_SECRET="${django_secret}" \
      --from-literal=OIDC_RP_CLIENT_ID="${client_id}" \
      --from-literal=OIDC_RP_CLIENT_SECRET="${client_secret}"
    echo "  [done]"
  else
    echo "[portal] WARNING: cannot configure Secret '${SECRET_NAME}' - missing client.yaml"
  fi
fi
