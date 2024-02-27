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
NAMESPACE="um"

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="dummy-service-open"
else
  name="dummy-service"
fi

main() {
  # deploy the service
  dummyService
  # protect the service (optional)
  if [ "${REQUIRE_DUMMY_SERVICE_PROTECTION}" = "true" ]; then
    echo -e "\nProtect dummy-service..."
    createDummyServiceClient
    dummyServiceProtection
  fi
}

dummyService() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall dummy-service
  else
    serviceValues | helm ${ACTION_HELM} dummy-service dummy -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.0.1
  fi
}

serviceValues() {
  cat - <<EOF
ingress:
  enabled: ${OPEN_INGRESS}
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
  hosts:
    - host: ${name}.${domain}
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - hosts:
        - ${name}.${domain}
      secretName: ${name}-tls
EOF
}

createDummyServiceClient() {
  # Create the client
  ../bin/create-client \
    -a $(httpScheme)://identity.keycloak.${domain} \
    -i $(httpScheme)://identity-api.${domain} \
    -r "${IDENTITY_REALM}" \
    -u "${IDENTITY_SERVICE_ADMIN_USER}" \
    -p "${IDENTITY_SERVICE_ADMIN_PASSWORD}" \
    -c "${IDENTITY_SERVICE_ADMIN_CLIENT}" \
    --id=dummy-service \
    --name="Dummy Service Gatekeeper" \
    --secret="${IDENTITY_SERVICE_DEFAULT_SECRET}" \
    --description="Client to be used by Dummy Service Gatekeeper" \
    --resource="eric" --uris='/eric/*' --scopes=view --users="eric" \
    --resource="bob" --uris='/bob/*' --scopes=view --users="bob" \
    --resource="alice" --uris='/alice/*' --scopes=view --users="alice"
}

dummyServiceProtection() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall dummy-service-protection
  else
    serviceProtectionValues | helm ${ACTION_HELM} dummy-service-protection identity-gatekeeper -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.0.11
  fi
}

serviceProtectionValues() {
  cat - <<EOF
fullnameOverride: dummy-service-protection
config:
  client-id: dummy-service
  discovery-url: $(httpScheme)://identity.keycloak.${domain}/realms/master
  cookie-domain: ${domain}
targetService:
  host: dummy-service.${domain}
  name: dummy-service
  port:
    number: 80
# Values for secret 'dummy-service-protection'
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
EOF
}

main "$@"
