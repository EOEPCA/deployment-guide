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
else
  name="zoo"
fi

main() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall ades
  else
    values | helm ${ACTION_HELM} zoo-project-dru zoo-project-dru -f - \
      --repo https://zoo-project.github.io/charts/ \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 0.2.6
    # values | helm ${ACTION_HELM} zoo-project-dru /home/rconway/develop/EOEPCA/zoo-project-charts/zoo-project-dru -f - \
    #   --namespace "${NAMESPACE}" --create-namespace
  fi
}

values() {
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
$(workspacePrefix)
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
    if [ "${USE_TLS}" = "true" ]; then scheme="https"; else scheme="http"; fi
    cat - <<EOF
  hosturl: ${scheme}://zoo.${domain}
EOF
  fi
}

workspacePrefix() {
  if [ "${STAGEOUT_TARGET}" = "workspace" ]; then
  cat - <<EOF
      workspace_prefix=ws
EOF
  fi
}

# Destination service for stage-out
# If STAGEOUT_TARGET is "workspace" then these details will be looked-up from the user's workspace
stageOutConfig() {
  if [ "${STAGEOUT_TARGET}" = "minio" ]; then
    cat - <<EOF
    STAGEOUT_AWS_SERVICEURL: https://minio.${domain}
    STAGEOUT_AWS_ACCESS_KEY_ID: ${MINIO_ROOT_USER}
    STAGEOUT_AWS_SECRET_ACCESS_KEY: ${MINIO_ROOT_PASSWORD}
    STAGEOUT_AWS_REGION: RegionOne
    STAGEOUT_OUTPUT: eoepca
EOF
  fi
}

stageOutYaml() {
  cat - <<EOF
    stageout.yaml: |-
$(cat zoo-files/stageout.yaml | sed 's/^/      /')
$(cat zoo-files/stageout.py | sed 's/^/      /' | sed 's/^/          /')
EOF
}

main "$@"
