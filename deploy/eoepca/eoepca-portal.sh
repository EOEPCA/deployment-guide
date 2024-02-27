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

NAMESPACE="demo"

main() {
  # deploy the service
  deployService
  # create the Keycloak client
  createClient
}

deployService() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall eoepca-portal
  else
    # helm chart
    # serviceValues | helm ${ACTION_HELM} eoepca-portal eoepca-portal -f - \
    serviceValues | helm ${ACTION_HELM} eoepca-portal ~/develop/EOEPCA/helm-charts-dev/charts/eoepca-portal -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.0.13
  fi
}

serviceValues() {
  cat - <<EOF
# image:
#   tag: "demo"
configMap:
  identity_url: "$(httpScheme)://keycloak.${domain}"
  realm: "${IDENTITY_REALM}"
  client_id: "eoepca-portal"
  identity_api_url: "$(httpScheme)://identity.api.${domain}"
  ades_url: "$(httpScheme)://zoo.${domain}/ogc-api/processes"
  resource_catalogue_url: "$(httpScheme)://resource-catalogue.${domain}"
  data_access_url: "$(httpScheme)://data-access.${domain}"
  workspace_url: "$(httpScheme)://workspace-api.${domain}"
  workspace_docs_url: "$(httpScheme)://workspace-api.${domain}/docs#"
  images_registry_url: "$(httpScheme)://harbor.${domain}"
  dummy_service_url: "$(httpScheme)://dummy-service.${domain}"
  access_token_name: "auth_user_id"
  access_token_domain: ".${domain}"
  refresh_token_name: "auth_refresh_token"
  refresh_token_domain: ".${domain}"
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
  hosts:
    - host: eoepca-portal.${domain}
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: eoepca-portal-tls
      hosts:
        - eoepca-portal.${domain}
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
    --id=eoepca-portal \
    --name="EOEPCA Portal" \
    --public \
    --description="Client to be used by the EOEPCA Portal"
}

main "$@"
