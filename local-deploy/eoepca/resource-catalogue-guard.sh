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
  context: resource-catalogue
  pep: resource-catalogue-pep
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
  fullnameOverride: resource-catalogue-agent
  nginxIntegration:
    enabled: true
    hosts:
      - host: resource-catalogue
        paths:
          - path: /(.*)
            service:
              name: resource-catalogue-service
              port: 80
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/rewrite-target: /\$1
  client:
    credentialsSecretName: "resman-client"
  logging:
    level: "info"
  unauthorizedResponse: 'Bearer realm="https://auth.${domain}/oxauth/auth/passport/passportlogin.htm"'
  openAccess: true  # access for any authenticated user
  insecureTlsSkipVerify: true
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall resource-catalogue-guard
else
  values | helm ${ACTION_HELM} resource-catalogue-guard resource-guard -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace "${NAMESPACE}" --create-namespace \
    --version 1.0.0
fi
