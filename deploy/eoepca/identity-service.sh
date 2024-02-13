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
    values | helm ${ACTION_HELM} identity-service identity-service -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.0.91
    # values | helm ${ACTION_HELM} identity-service ~/develop/EOEPCA/helm-charts-dev/charts/identity-service -f - \
    #   --namespace "${NAMESPACE}" --create-namespace

    createIdentityApiClient
    createTestUsers
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
      # - name: AUTH_SERVER_URL  # see configMap.authServerUrl instead
      #   value: http://localhost
      - name: ADMIN_USERNAME
        value: ${IDENTITY_SERVICE_ADMIN_USER}
      # - name: ADMIN_PASSWORD  # see secrets.adminPassword instead
      #   value: admin
      - name: REALM
        value: ${IDENTITY_REALM}
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

createIdentityApiClient() {
  # Use port-forwarding to go directly to the identity-api service
  echo "Waiting for Identity API service to be ready..."
  kubectl -n "${NAMESPACE}" rollout status deploy/identity-api --watch
  echo "Establish port-forwarding to Identity API service on port ${TEMP_FORWARDING_PORT}..."
  kubectl -n "${NAMESPACE}" port-forward svc/identity-api "${TEMP_FORWARDING_PORT}":http >/dev/null &
  portForwardPid=$!
  sleep 1

  # Create the client
  ../bin/create-client \
    -a https://identity.keycloak.${domain} \
    -i http://localhost:${TEMP_FORWARDING_PORT} \
    -r "${IDENTITY_REALM}" \
    -u "${IDENTITY_SERVICE_ADMIN_USER}" \
    -p "${IDENTITY_SERVICE_ADMIN_PASSWORD}" \
    -c "${IDENTITY_SERVICE_ADMIN_CLIENT}" \
    --id=identity-api \
    --name="Identity API Gatekeeper" \
    --secret="${IDENTITY_SERVICE_DEFAULT_SECRET}" \
    --description="Client to be used by Identity API Gatekeeper" \
    --resource="admin" \
      --uris='/*' \
      --scopes=view \
      --users="${IDENTITY_SERVICE_ADMIN_USER}"

  # Stop the port-forwarding
  echo "Stop port-forwarding to Identity API service on port ${TEMP_FORWARDING_PORT}..."
  kill -TERM $portForwardPid
}

createTestUsers() {
  createTestUser "eric"
  createTestUser "bob"
  createTestUser "alice"
}

createTestUser() {
  user=""$1
  echo "Creating user ${user}"

  payload=$(cat - <<EOF
{
  "username": "${user}",
  "enabled": true,
  "credentials": [{
    "type": "password",
    "value": "${IDENTITY_SERVICE_DEFAULT_SECRET}",
    "temporary": false
  }]
}
EOF
  )

  # env vars expected by runcurl
  username="${IDENTITY_SERVICE_ADMIN_USER}"
  password="${IDENTITY_SERVICE_ADMIN_PASSWORD}"
  client="${IDENTITY_SERVICE_ADMIN_CLIENT}"
  auth_server="https://identity.keycloak.${domain}"
  realm="${IDENTITY_REALM}"

  runcurl -a -d "Create User ${user}" -r 201 -- \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -X POST --data "${payload}" \
    "https://identity.keycloak.${domain}/admin/realms/${realm}/users"
}

main "$@"
