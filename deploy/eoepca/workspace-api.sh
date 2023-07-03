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
NAMESPACE="rm"
UMA_CLIENT_SECRET="resman-client"

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="workspace-api-open"
  nameResourceCatalogue="resource-catalogue-open"
  nameDataAccess="data-access-open"
else
  name="workspace-api"
  nameResourceCatalogue="resource-catalogue"
  nameDataAccess="data-access-open"
fi

main() {
  helmChart
  workspaceTemplates
  helmRepositories
  harborPasswordSecret
  minioBucketApi
}

# Values for helm chart
values() {
  cat - <<EOF
fullnameOverride: workspace-api
# image:
#   tag: "1.3-dev5"
#   pullPolicy: Always
ingress:
  enabled: ${OPEN_INGRESS}
  hosts:
    - host: ${name}.${domain}
      paths: ["/"]
  tls:
    - hosts:
        - ${name}.${domain}
      secretName: ${name}-tls
fluxHelmOperator:
  enabled: ${INSTALL_FLUX}
prefixForName: "guide-user"
workspaceSecretName: "bucket"
namespaceForBucketResource: ${NAMESPACE}
s3Endpoint: "https://minio.${domain}"
s3Region: "RegionOne"
harborUrl: "https://harbor.${domain}"
harborUsername: "admin"
harborPasswordSecretName: "harbor"
umaClientSecretName: "${UMA_CLIENT_SECRET}"
umaClientSecretNamespace: ${NAMESPACE}
workspaceChartsConfigMap: "workspace-charts"
bucketEndpointUrl: "http://minio-bucket-api:8080/bucket"
pepBaseUrl: "http://workspace-api-pep:5576/resources"
autoProtectionEnabled: $(if [ "${OPEN_INGRESS}" = "true" ]; then echo -n "false"; else echo -n "true"; fi)
EOF
}

# Helm Chart
helmChart() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace rm uninstall workspace-api
  else
    values | helm ${ACTION_HELM} workspace-api rm-workspace-api -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.3.5
  fi
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
  export NAMESPACE UMA_CLIENT_SECRET public_ip domain nameResourceCatalogue nameDataAccess
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

valuesMinioBucketApi() {
  cat - <<EOF
fullnameOverride: minio-bucket-api
minIOServerEndpoint: https://minio.${domain}
accessCredentials:
  secretName: minio-auth
EOF
}

minioBucketApi() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace rm uninstall rm-minio-bucket-api
  else
    valuesMinioBucketApi | helm ${ACTION_HELM} rm-minio-bucket-api rm-minio-bucket-api -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 0.0.4
  fi
}

main "$@"
