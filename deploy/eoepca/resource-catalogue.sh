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
  name="resource-catalogue-open"
else
  name="resource-catalogue"
fi

main() {
  # deploy the service
  deployService
  # protect the service (optional)
  if [ "${REQUIRE_RESOURCE_CATALOGUE_PROTECTION}" = "true" ]; then
    echo -e "\nProtect Resource Catalogue..."
    createClient
    deployProtection
  fi
}

deployService() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace ${NAMESPACE} uninstall resource-catalogue
  else
    serviceValues | helm ${ACTION_HELM} resource-catalogue rm-resource-catalogue -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace ${NAMESPACE} --create-namespace \
      --version 1.4.0
  fi
}

serviceValues() {
  cat - <<EOF
global:
  namespace: ${NAMESPACE}
ingress:
  enabled: ${OPEN_INGRESS}
  name: ${name}
  host: ${name}.${domain}
  tls_host: ${name}.${domain}
  tls_secret_name: ${name}-tls
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
db:
  volume_storage_type: ${RESOURCE_CATALOGUE_STORAGE}
pycsw:
  # image:
  #   # repository: geopython/pycsw
  #   tag: "eoepca-staging"
  #   pullPolicy: Always
  config:
    server:
      url: $(httpScheme)://${name}.${domain}/
    manager:
      transactions: "true"
      allowed_ips: "*"
EOF
}

createClient() {
  # Create the client
  ../bin/create-client \
    -a $(httpScheme)://identity.keycloak.${domain} \
    -i $(httpScheme)://identity-api.${domain} \
    -r "${IDENTITY_REALM}" \
    -u "${IDENTITY_SERVICE_ADMIN_USER}" \
    -p "${IDENTITY_SERVICE_ADMIN_PASSWORD}" \
    -c "${IDENTITY_SERVICE_ADMIN_CLIENT}" \
    --id=resource-catalogue \
    --name="Resource Catalogue Gatekeeper" \
    --secret="${IDENTITY_SERVICE_DEFAULT_SECRET}" \
    --description="Client to be used by Resource Catalogue Gatekeeper"
}

deployProtection() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall resource-catalogue-protection
  else
    serviceProtectionValues | helm ${ACTION_HELM} resource-catalogue-protection identity-gatekeeper -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.0.11
  fi
}

serviceProtectionValues() {
  cat - <<EOF
fullnameOverride: resource-catalogue-protection
config:
  client-id: resource-catalogue
  discovery-url: $(httpScheme)://identity.keycloak.${domain}/realms/master
  cookie-domain: ${domain}
targetService:
  host: ${name}.${domain}
  name: resource-catalogue-service
  port:
    number: 80
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
  serverSnippets:
    custom: |-
      # Open access...
      location ~ ^/ {
        proxy_pass {{ include "identity-gatekeeper.targetUrl" . }}$request_uri;
      }
EOF
}

main "$@"
