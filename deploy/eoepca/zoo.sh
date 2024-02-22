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
NAMESPACE="zoo"

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="zoo-open"
  workspace_api_name="workspace-api-open"
else
  name="zoo"
  workspace_api_name="workspace-api"
fi

main() {
  # deploy the service
  deployService
  # protect the service (optional)
  if [ "${REQUIRE_ADES_PROTECTION}" = "true" ]; then
    echo -e "\nProtect ADES (zoo-project-dru)..."
    createClient
    deployProtection
  fi
}

deployService() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall zoo-project-dru
  else
    serviceValues | helm ${ACTION_HELM} zoo-project-dru zoo-project-dru -f - \
      --repo https://zoo-project.github.io/charts/ \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 0.2.6
    # serviceValues | helm ${ACTION_HELM} zoo-project-dru /home/rconway/develop/EOEPCA/zoo-project-charts/zoo-project-dru -f - \
    #   --namespace "${NAMESPACE}" --create-namespace
  fi
}

serviceValues() {
  cat - <<EOF
cookiecutter:
  templateUrl: https://github.com/EOEPCA/eoepca-proc-service-template.git
  templateBranch: master
zoofpm:
  image:
    tag: ${PROCESSING_ZOO_IMAGE}
zookernel:
  image:
    tag: ${PROCESSING_ZOO_IMAGE}
customConfig:
  main:
    eoepca: |-
      domain=${domain}
$(workspaceConfig)
files:
  # Directory 'files/cwlwrapper-assets' - assets for ConfigMap 'XXX-cwlwrapper-config'
  cwlwrapperAssets:
    # main.yaml: ""
    # rules.yaml: ""
    # stagein.yaml: ""
    # stageout.yaml: ""
$(stageOutYaml)
workflow:
  defaultMaxRam: ${PROCESSING_MAX_RAM}
  defaultMaxCores: ${PROCESSING_MAX_CORES}
  inputs:
    STAGEIN_AWS_SERVICEURL: http://data.cloudferro.com
    STAGEIN_AWS_ACCESS_KEY_ID: test
    STAGEIN_AWS_SECRET_ACCESS_KEY: test
    STAGEIN_AWS_REGION: RegionOne
$(stageOutConfig)
  nodeSelector:
    minikube.k8s.io/primary: "true"
  storageClass: ${ADES_STORAGE}
ingress:
  enabled: ${OPEN_INGRESS}
$(hostUrl)
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
persistence:
  procServicesStorageClass: ${ADES_STORAGE}
  storageClass: ${ADES_STORAGE}
  tmpStorageClass: ${ADES_STORAGE}
postgresql:
  primary:
    persistence:
      storageClass: ${ADES_STORAGE}
  readReplicas:
    persistence:
      storageClass: ${ADES_STORAGE}
rabbitmq:
  persistence:
    storageClass: ${ADES_STORAGE}
iam:
  enabled: false
EOF
}

hostUrl() {
  if [ "${REQUIRE_ADES_PROTECTION}" = "true" ]; then
    cat - <<EOF
  hosturl: $(httpScheme)://zoo.${domain}
EOF
  fi
}

workspaceConfig() {
  if [ "${STAGEOUT_TARGET}" = "workspace" ]; then
  cat - <<EOF
      workspace_url=$(httpScheme)://${workspace_api_name}.${domain}
      workspace_prefix=ws
EOF
  fi
}

# Destination service for stage-out - in particular for STAGEOUT_TARGET "minio".
# If STAGEOUT_TARGET is "workspace" then these details will be looked-up (and overidden)
# from the user's workspace - but, regardless, set these here as a fallback.
stageOutConfig() {
  cat - <<EOF
    STAGEOUT_AWS_SERVICEURL: $(httpScheme)://minio.${domain}
    STAGEOUT_AWS_ACCESS_KEY_ID: ${MINIO_ROOT_USER}
    STAGEOUT_AWS_SECRET_ACCESS_KEY: ${MINIO_ROOT_PASSWORD}
    STAGEOUT_AWS_REGION: RegionOne
    STAGEOUT_OUTPUT: eoepca
EOF
}

stageOutYaml() {
  cat - <<EOF
    stageout.yaml: |-
$(cat zoo-files/stageout.yaml | sed 's/^/      /')
$(cat zoo-files/stageout.py | sed 's/^/      /' | sed 's/^/          /')
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
    --id=ades \
    --name="ADES Gatekeeper" \
    --secret="${IDENTITY_SERVICE_DEFAULT_SECRET}" \
    --description="Client to be used by ADES Gatekeeper" \
    --resource="eric" --uris='/eric/*' --scopes=view --users="eric" \
    --resource="bob" --uris='/bob/*' --scopes=view --users="bob" \
    --resource="alice" --uris='/alice/*' --scopes=view --users="alice"
}

deployProtection() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall zoo-project-dru-protection
  else
    serviceProtectionValues | helm ${ACTION_HELM} zoo-project-dru-protection identity-gatekeeper -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.0.10
  fi
}

serviceProtectionValues() {
  cat - <<EOF
nameOverride: zoo-project-dru-protection
config:
  client-id: ades
  discovery-url: $(httpScheme)://identity.keycloak.${domain}/realms/master
  cookie-domain: ${domain}
targetService:
  host: ${name}.${domain}
  name: zoo-project-dru-service
  port:
    number: 80
# Values for secret 'zoo-project-dru-protection'
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
      location ~ /(ogc-api/api|swagger-ui) {
        proxy_pass {{ include "identity-gatekeeper.targetUrl" . }}$request_uri;
      }
EOF
}

main "$@"
