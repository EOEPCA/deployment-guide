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

values() {
  cat - <<EOF
domain: ${domain}
authHost: auth
configmap:
  user_prefix: eoepca-user
image:
  tag: ractest
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall django-portal
else
  values | helm ${ACTION_HELM} django-portal django-portal -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace demo --create-namespace \
    --version 0.1.11
fi

# TODO - do this properly
secret() {
  cat - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: django-secrets
type: Opaque
data:
  DJANGO_SECRET: bXJreWVjdmdXZ0VaNDFhWnQ3T19YdjhIZ1N5RkJsYjIxek13ZjVQSERmdw==
  OIDC_RP_CLIENT_ID: ZjUwOTIxMTctZjA5Mi00MTU5LTkwNjQtMzdhNmU2ODZlNWQz
  OIDC_RP_CLIENT_SECRET: ZGFmYTc0ZmYtYWVkYy00ODA1LTlhZGItNjkxMDMxZDQxOGE4
EOF
}

secret | kubectl -n demo ${ACTION_KUBECTL} -f -
