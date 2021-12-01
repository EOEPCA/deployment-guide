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

eric_id="${2:-c14974be-b32f-44f3-97be-b216676bb40e}"
bob_id="${3:-44f601ba-3fad-4d22-b2ae-ce8fafcdd763}"
public_ip="${4:-${default_public_ip}}"
domain="${5:-${default_domain}}"
NAMESPACE="test"
SECRET_NAME="test-client"

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
  context: dummy-service
  pep: dummy-service-pep
  domain: ${domain}
  nginxIp: ${public_ip}
  certManager:
    clusterIssuer: letsencrypt-staging
#---------------------------------------------------------------------------
# PEP values
#---------------------------------------------------------------------------
pep-engine:
  configMap:
    asHostname: auth
    pdpHostname: auth
  customDefaultResources:
    - name: "Eric's space"
      description: "Protected Access for eric to his space in the dummy service"
      resource_uri: "/ericspace"
      scopes: []
      default_owner: "${eric_id}"
    - name: "Bob's space"
      description: "Protected Access for bob to his space in the dummy service"
      resource_uri: "/bobspace"
      scopes: []
      default_owner: "${bob_id}"
  nginxIntegration:
    enabled: false
    # hostname: dummy-service-auth
  # image:
  #   pullPolicy: Always
  volumeClaim:
    name: dummy-service-pep-pvc
    create: true
#---------------------------------------------------------------------------
# UMA User Agent values
#---------------------------------------------------------------------------
uma-user-agent:
  fullnameOverride: dummy-service-agent
  # image:
  #   tag: mytest
  #   pullPolicy: Always
  nginxIntegration:
    enabled: true
    hosts:
      - host: dummy-service
        paths:
          - path: /(.*)
            service:
              name: dummy-service
              port: 80
    annotations:
      nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
      nginx.ingress.kubernetes.io/enable-cors: "true"
      nginx.ingress.kubernetes.io/rewrite-target: /$1
  client:
    credentialsSecretName: "test-client"
  logging:
    level: "debug"
  unauthorizedResponse: 'Bearer realm="https://auth.${domain}/oxauth/auth/passport/passportlogin.htm"'
  insecureTlsSkipVerify: true
#---------------------------------------------------------------------------
# END values
#---------------------------------------------------------------------------
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall dummy-service-guard
else
  values | helm ${ACTION_HELM} dummy-service-guard resource-guard -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace "${NAMESPACE}" --create-namespace \
    --version 0.0.54
fi