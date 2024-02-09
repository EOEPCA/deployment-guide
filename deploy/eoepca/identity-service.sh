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
NAMESPACE="um"

main() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall identity-service
  else
    # helm chart
    # values | helm ${ACTION_HELM} identity-service identity-service -f - \
    #   --repo https://eoepca.github.io/helm-charts \
    #   --namespace "${NAMESPACE}" --create-namespace \
    #   --version 1.0.90
    values | helm ${ACTION_HELM} identity-service ~/develop/EOEPCA/helm-charts-dev/charts/identity-service -f - \
      --namespace "${NAMESPACE}" --create-namespace
    
    # secrets
    # createSecrets

    # # create client
    # # zzz use port-forward for the `-i` arg
    # ./deploy/bin/create-client \
    #   -a https://identity.keycloak.eoepca.svc.rconway.uk \
    #   -i https://identity-api-protected.eoepca.svc.rconway.uk \
    #   -u admin -p changeme \
    #   --id=identity-api \
    #   --name="Identity API Gatekeeper" \
    #   --description="Client to be used by Identity API Gatekeeper" \
    #   -c admin-cli \
    #   -r master
  fi
}

values() {
  cat - <<EOF
volumeClaim:
  name: eoepca-userman-pvc
  create: false
identity-keycloak:
  # Values for secret 'identity-keycloak'
  secrets:
    # Note - if ommitted, these can instead be set by creating the secret independently.
    kcDbPassword: "${IDENTITY_POSTGRES_PASSWORD}"
    keycloakAdminPassword: "${IDENTITY_SERVICE_ADMIN_PASSWORD}"
  ingress:
    enabled: true
    className: nginx
    annotations:
      ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
      nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
      cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
    hosts:
      - host: identity.keycloak.${domain}
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: identity-keycloak-tls-certificate
        hosts:
          - identity.keycloak.${domain}
identity-postgres:
  # Values for secret 'identity-postgres'
  secrets:
    # Note - if ommitted, these can instead be set by creating the secret independently.
    postgresPassword: "${IDENTITY_POSTGRES_PASSWORD}"
    pgPassword: "${IDENTITY_POSTGRES_PASSWORD}"
  volumeClaim:
    name: eoepca-userman-pvc
identity-api:
  # Values for secret 'identity-api'
  secrets:
    # Note - if ommitted, these can instead be set by creating the secret independently.
    adminPassword: "${IDENTITY_SERVICE_ADMIN_PASSWORD}"
  ingress:
    enabled: false  # ingress is provided by the associated gatekeeper instance
  configMap:
    # NOTE this can equally set via the AUTH_SERVER_URL env var (see below)
    authServerUrl: https://identity.keycloak.${domain}
  deployment:
    # Config values that can be passed via env vars (defaults shown below)
    extraEnv:
      # - name: AUTH_SERVER_URL
      #   value: http://localhost
      # - name: ADMIN_USERNAME
      #   value: admin
      # - name: ADMIN_PASSWORD
      #   value: admin
      # - name: REALM
      #   value: master
      # - name: VERSION
      #   value: v1.0.0
      - name: LOG_LEVEL
        value: DEBUG
identity-api-gatekeeper:
  nameOverride: identity-api-protection
  config:
    client-id: identity-api
    discovery-url: https://identity.keycloak.${domain}/realms/master
    cookie-domain: ${domain}
  targetService:
    host: identity-api-protected.${domain}
    name: identity-api
    port:
      number: 8080
  # Values for secret 'um-identity-service-identity-api-protection'
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

createSecrets() {
  createSecretForKeycloak
  createSecretForPostgres
  createSecretForIdentityApi
  # createSecretForIdentityApiGatekeeper
}

createSecretForKeycloak() {
  kubectl -n "${NAMESPACE}" create secret generic "identity-keycloak" \
    --from-literal=KC_DB_PASSWORD="${IDENTITY_POSTGRES_PASSWORD}" \
    --from-literal=KEYCLOAK_ADMIN_PASSWORD="${IDENTITY_SERVICE_ADMIN_PASSWORD}"
}

createSecretForPostgres() {
  kubectl -n "${NAMESPACE}" create secret generic "identity-postgres" \
    --from-literal=PGPASSWORD="${IDENTITY_POSTGRES_PASSWORD}" \
    --from-literal=POSTGRES_PASSWORD="${IDENTITY_POSTGRES_PASSWORD}"
}

createSecretForIdentityApi() {
  kubectl -n "${NAMESPACE}" create secret generic "identity-api" \
    --from-literal=ADMIN_PASSWORD="${IDENTITY_SERVICE_ADMIN_PASSWORD}"
}

createSecretForIdentityApiGatekeeper() {
  kubectl -n "${NAMESPACE}" create secret generic "identity-api" \
    --from-literal=PROXY_CLIENT_SECRET="${zzz}" \
    --from-literal=PROXY_ENCRYPTION_KEY="${IDENTITY_GATEKEEPER_ENCRYPTION_KEY}"
}

main "$@"
