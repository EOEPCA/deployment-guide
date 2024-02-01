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

eric_id="${2:-b8c8c62a-892c-4953-b44d-10a12eb762d8}"
bob_id="${3:-57e3e426-581e-4a01-b2b8-f731a928f2db}"
public_ip="${4:-${default_public_ip}}"
domain="${5:-${default_domain}}"
NAMESPACE="zoo"
SECRET_NAME="zoo-client"

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
  context: zoo
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
  customDefaultResources:
    - name: "ZOO Service for user 'eric'"
      description: "Protected Access for eric to his space in ZOO"
      resource_uri: "/eric"
      scopes: []
      default_owner: "${eric_id}"
    - name: "ZOO Service for user 'bob'"
      description: "Protected Access for bob to his space in ZOO"
      resource_uri: "/bob"
      scopes: []
      default_owner: "${bob_id}"
  volumeClaim:
    name: eoepca-zoo-pvc
    create: false
#---------------------------------------------------------------------------
# UMA User Agent values
#---------------------------------------------------------------------------
uma-user-agent:
  nginxIntegration:
    enabled: true
    hosts:
      - host: zoo
        paths:
          - path: /(.*)
            service:
              name: zoo-project-dru-service
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
  openAccess: false
  insecureTlsSkipVerify: true
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall zoo-guard
else
  values | helm ${ACTION_HELM} zoo-guard resource-guard -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace "${NAMESPACE}" --create-namespace \
    --version 1.3.2
fi
