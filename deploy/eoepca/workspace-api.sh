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
WORKSPACE_API_IAM_CLIENT_ID="workspace-api"

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="workspace-api-open"
  nameResourceCatalogue="resource-catalogue-open"
  nameDataAccess="data-access-open"
else
  name="workspace-api"
  nameResourceCatalogue="resource-catalogue"
  nameDataAccess="data-access"
fi

main() {
  deployWorkspaceApi
  workspaceTemplates
  helmRepositories
  harborPasswordSecret
  deployMinioBucketApi
  createClient
  deployProtection
}

# Deploy the Workspace API
deployWorkspaceApi() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace rm uninstall workspace-api
  else
    valuesWorkspaceApi | helm ${ACTION_HELM} workspace-api rm-workspace-api -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.4.1
  fi
}

# Values for Workspace API helm chart
valuesWorkspaceApi() {
  cat - <<EOF
fullnameOverride: workspace-api
# image:
#   tag: integration
#   pullPolicy: Always
ingress:
  enabled: ${OPEN_INGRESS}
  annotations:
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
  hosts:
    - host: ${name}.${domain}
      paths: ["/"]
  tls:
    - hosts:
        - ${name}.${domain}
      secretName: ${name}-tls
fluxHelmOperator:
  enabled: ${INSTALL_FLUX}
prefixForName: "ws"
workspaceSecretName: "bucket"
namespaceForBucketResource: ${NAMESPACE}
s3Endpoint: "$(httpScheme)://minio.${domain}"
s3Region: "RegionOne"
harborUrl: "$(httpScheme)://harbor.${domain}"
harborUsername: "admin"
harborPasswordSecretName: "harbor"
workspaceChartsConfigMap: "workspace-charts"
bucketEndpointUrl: "http://minio-bucket-api:8080/bucket"
keycloakIntegration:
  enabled: true
  keycloakUrl: "$(httpScheme)://identity.keycloak.${domain}"
  realm: "${IDENTITY_REALM}"
  identityApiUrl: "$(httpScheme)://identity-api-protected.${domain}"
  workspaceApiIamClientId: "${WORKSPACE_API_IAM_CLIENT_ID}"
  defaultIamClientSecret: "${IDENTITY_SERVICE_DEFAULT_SECRET}"
EOF
}

workspaceTemplates() {
  cleanUp
  substituteVariables
  applyKustomization
  cleanUp
}

cleanUp() {
  rm -rf workspace-templates-tmp
}

substituteVariables() {
  mkdir workspace-templates-tmp
  export http_scheme="$(httpScheme)"
  export NAMESPACE domain nameResourceCatalogue nameDataAccess
  for template in workspace-templates/*.yaml; do
    envsubst <$template >workspace-templates-tmp/$(basename $template)
  done
}

applyKustomization() {
  kubectl ${ACTION_KUBECTL} -k workspace-templates-tmp
}

helmRepositories() {
  cat - <<EOF | kubectl ${ACTION_KUBECTL} -f -
---
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: eoepca
  namespace: ${NAMESPACE}
spec:
  interval: 2m
  url: https://eoepca.github.io/helm-charts/
EOF
}

harborPasswordSecret() {
  echo -e "\nHarbor password secret..."
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    kubectl -n "${NAMESPACE}" delete secret harbor
  else
    kubectl -n "${NAMESPACE}" create secret generic harbor \
      --from-literal=HARBOR_ADMIN_PASSWORD="${HARBOR_ADMIN_PASSWORD}" \
      --dry-run=client -oyaml \
      | kubectl apply -f -
  fi
}

deployMinioBucketApi() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace rm uninstall rm-minio-bucket-api
  else
    valuesMinioBucketApi | helm ${ACTION_HELM} rm-minio-bucket-api rm-minio-bucket-api -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 0.0.4
  fi
}

valuesMinioBucketApi() {
  cat - <<EOF
fullnameOverride: minio-bucket-api
minIOServerEndpoint: $(httpScheme)://minio.${domain}
accessCredentials:
  secretName: minio-auth
EOF
}

createClient() {
  # Create the client
  ../bin/create-client \
    -a $(httpScheme)://identity.keycloak.${domain} \
    -i $(httpScheme)://identity-api-protected.${domain} \
    -r "${IDENTITY_REALM}" \
    -u "${IDENTITY_SERVICE_ADMIN_USER}" \
    -p "${IDENTITY_SERVICE_ADMIN_PASSWORD}" \
    -c "${IDENTITY_SERVICE_ADMIN_CLIENT}" \
    --id="${WORKSPACE_API_IAM_CLIENT_ID}" \
    --name="Workspace API Gatekeeper" \
    --secret="${IDENTITY_SERVICE_DEFAULT_SECRET}" \
    --description="Client to be used by Workspace API Gatekeeper" \
    --resource="admin" --uris='/*' --scopes=view --users="${IDENTITY_SERVICE_ADMIN_USER}"
}

deployProtection() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall workspace-api-protection
  else
    serviceProtectionValues | helm ${ACTION_HELM} workspace-api-protection identity-gatekeeper -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.0.10
  fi
}

serviceProtectionValues() {
  cat - <<EOF
nameOverride: workspace-api-protection
config:
  client-id: workspace-api
  discovery-url: $(httpScheme)://identity.keycloak.${domain}/realms/master
  cookie-domain: ${domain}
targetService:
  host: ${name}.${domain}
  name: workspace-api
  port:
    number: 8080
# Values for secret 'workspace-api-protection'
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
  serverSnippets:
    custom: |-
      # Open access to some endpoints, including Swagger UI
      location ~ ^/(docs|openapi.json|probe) {
        proxy_pass {{ include "identity-gatekeeper.targetUrl" . }}$request_uri;
      }
EOF
}

main "$@"
