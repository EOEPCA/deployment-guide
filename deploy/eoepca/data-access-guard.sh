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

public_ip="${2:-${default_public_ip}}"
domain="${3:-${default_domain}}"
NAMESPACE="rm"
SECRET_NAME="resman-client"

if [ -f client.yaml ]; then
  echo "Creating secret ${SECRET_NAME} in namespace ${NAMESPACE}..."
  kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
    --from-file=client.yaml \
    --dry-run=client -o yaml \
    | kubectl ${ACTION_KUBECTL} -f -
  echo "  [done]"
fi

values() {
  cat - <<EOF
#---------------------------------------------------------------------------
# Global values
#---------------------------------------------------------------------------
global:
  context: data-access
  domain: ${domain}
  nginxIp: ${public_ip}
  certManager:
    clusterIssuer: ${TLS_CLUSTER_ISSUER}
#---------------------------------------------------------------------------
# PEP values
#---------------------------------------------------------------------------
pep-engine:
  configMap:
    asHostname: auth
    pdpHostname: auth
  volumeClaim:
    name: eoepca-resman-pvc
    create: false
#---------------------------------------------------------------------------
# UMA User Agent values
#---------------------------------------------------------------------------
uma-user-agent:
  nginxIntegration:
    enabled: true
    hosts:
      - host: data-access
        paths:
          - path: /(ows.*)
            service:
              name: data-access-renderer
              port: 80
          - path: /(opensearch.*)
            service:
              name: data-access-renderer
              port: 80
          - path: /(coverages/metadata.*)
            service:
              name: data-access-renderer
              port: 80
          - path: /(admin.*)
            service:
              name: data-access-renderer
              port: 80
          - path: /cache/(.*)
            service:
              name: data-access-cache
              port: 80
          - path: /(.*)
            service:
              name: data-access-client
              port: 80
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/rewrite-target: /\$1
  client:
    credentialsSecretName: "${SECRET_NAME}"
  logging:
    level: "info"
  unauthorizedResponse: 'Bearer realm="https://portal.${domain}/oidc/authenticate/"'
  openAccess: true  # access for any authenticated user
  insecureTlsSkipVerify: true
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall data-access-guard
else
  values | helm ${ACTION_HELM} data-access-guard resource-guard -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace "${NAMESPACE}" --create-namespace \
    --version 1.2.0
fi
