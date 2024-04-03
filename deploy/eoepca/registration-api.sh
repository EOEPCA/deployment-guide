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
NAMESPACE="rm"

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="registration-api-open"
else
  name="registration-api"
fi

main() {
  # deploy the service
  deployService
  # protect the service (optional)
  if [ "${REQUIRE_REGISTRATION_API_PROTECTION}" = "true" ]; then
    echo -e "\nProtect Registration API..."
    createClient
    deployProtection
  fi
}

deployService() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace ${NAMESPACE} uninstall registration-api
  else
    serviceValues | helm ${ACTION_HELM} registration-api rm-registration-api -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace ${NAMESPACE} --create-namespace \
      --version 1.4.0
  fi
}

serviceValues() {
  cat - <<EOF
fullnameOverride: registration-api
# image: # {}
  # repository: eoepca/rm-registration-api
  # pullPolicy: Always
  # Overrides the image tag whose default is the chart appVersion.
  # tag: "1.3-dev1"

ingress:
  enabled: ${OPEN_INGRESS}
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
  hosts:
    - host: ${name}.${domain}
      paths: ["/"]
  tls:
    - hosts:
        - ${name}.${domain}
      secretName: ${name}-tls

# some values for the workspace API
workspaceK8sNamespace: "${NAMESPACE}"
redisServiceName: "data-access-redis-master"
EOF
}

createClient() {
  # Create the client
  ../bin/create-client \
    -a $(httpScheme)://keycloak.${domain} \
    -i $(httpScheme)://identity-api.${domain} \
    -r "${IDENTITY_REALM}" \
    -u "${IDENTITY_SERVICE_ADMIN_USER}" \
    -p "${IDENTITY_SERVICE_ADMIN_PASSWORD}" \
    -c "${IDENTITY_SERVICE_ADMIN_CLIENT}" \
    --id=registration-api \
    --name="Registration API Gatekeeper" \
    --secret="${IDENTITY_SERVICE_DEFAULT_SECRET}" \
    --description="Client to be used by Registration API Gatekeeper"
}

deployProtection() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall registration-api-protection
  else
    serviceProtectionValues | helm ${ACTION_HELM} registration-api-protection identity-gatekeeper -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.0.12
  fi
}

serviceProtectionValues() {
  cat - <<EOF
fullnameOverride: registration-api-protection
config:
  client-id: registration-api
  discovery-url: $(httpScheme)://keycloak.${domain}/realms/master
  cookie-domain: ${domain}
targetService:
  host: ${name}.${domain}
  name: registration-api
  port:
    number: 8080
# Values for secret 'resource-catalogue-protection'
secrets:
  # Note - if ommitted, these can instead be set by creating the secret independently.
  clientSecret: "${IDENTITY_GATEKEEPER_CLIENT_SECRET}"
  encryptionKey: "${IDENTITY_GATEKEEPER_ENCRYPTION_KEY}"
ingress:
  enabled: true
  className: nginx
  annotations:
    ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/enable-cors: "true"
  # open access
  openUri:
    - ^.*
EOF
}

main "$@"
