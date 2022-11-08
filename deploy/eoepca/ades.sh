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

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="ades-open"
  workspaceApiName="workspace-api-open"
else
  name="ades"
  workspaceApiName="workspace-api"
fi

values() {
  cat - <<EOF
image:
  # tag: "2.0.3"
  pullPolicy: Always
workflowExecutor:
  inputs:
    STAGEIN_AWS_SERVICEURL: http://data.cloudferro.com
    STAGEIN_AWS_ACCESS_KEY_ID: test
    STAGEIN_AWS_SECRET_ACCESS_KEY: test
$(stageOut)
  # Workspace integration
  useResourceManager: $(if [ "${STAGEOUT_TARGET}" = "workspace" ]; then echo -n "true"; else echo -n "false"; fi)
  resourceManagerWorkspacePrefix: "guide-user"
  resourceManagerEndpoint: "https://${workspaceApiName}.${domain}"
  platformDomain: "https://auth.${domain}"
  # Kubernetes storage
  processingStorageClass: ${ADES_STORAGE}
  # Size of the Kubernetes Tmp Volumes
  processingVolumeTmpSize: "6Gi"
  # Size of the Kubernetes Output Volumes
  processingVolumeOutputSize: "6Gi"
  # Max ram to use for a job
  processingMaxRam: "8Gi"
  # Max number of CPU cores to use concurrently for a job
  processingMaxCores: "4"
wps:
  pepBaseUrl: "http://ades-pep:5576"
  usePep: "$(if [ "${OPEN_INGRESS}" = "true" ]; then echo false; else echo true; fi)"
persistence:
  storageClass: ${ADES_STORAGE}
ingress:
  enabled: ${OPEN_INGRESS}
  annotations:
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
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

# Destination service for stage-out
stageOut() {
  if [ "${STAGEOUT_TARGET}" = "minio" ]; then
    cat - <<EOF
    STAGEOUT_AWS_SERVICEURL: http://minio.${domain}
    STAGEOUT_AWS_ACCESS_KEY_ID: ${MINIO_ROOT_USER}
    STAGEOUT_AWS_SECRET_ACCESS_KEY: ${MINIO_ROOT_PASSWORD}
    STAGEOUT_AWS_REGION: us-east-1
    STAGEOUT_OUTPUT: s3://eoepca
EOF
  fi
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace proc uninstall ades
else
  values | helm ${ACTION_HELM} ades ades -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace proc --create-namespace \
    --version 2.0.1
fi
