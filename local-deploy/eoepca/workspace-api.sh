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

if [ "${OPEN_INGRESS}" = "true" ]; then
  name="workspace-api-open"
else
  name="workspace-api"
fi

main() {
  flux
  eoepcaHelmRepo
  helmChart
}

# Flux - a pre-requisite for the Workspace API
flux() {
  kubectl ${ACTION_KUBECTL} -f ./flux.yaml
}

eoepcaHelmRepo() {
  cat - <<EOF | kubectl ${ACTION_KUBECTL} -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
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

# Values for helm chart
values() {
  cat - <<EOF
fullnameOverride: workspace-api
ingress:
  enabled: ${OPEN_INGRESS}
  hosts:
    - host: ${name}.${domain}
      paths: ["/"]
  tls:
    - hosts:
        - ${name}.${domain}
      secretName: ${name}-tls
prefixForName: "guide-user"
workspaceSecretName: "bucket"
namespaceForBucketResource: ${NAMESPACE}
gitRepoResourceForHelmChartName: "eoepca"
gitRepoResourceForHelmChartNamespace: "${NAMESPACE}"
helmChartStorageClassName: "standard"
s3Endpoint: "https://cf2.cloudferro.com:8080"
s3Region: "RegionOne"
workspaceDomain: ${domain}
harborUrl: "https://harbor.${domain}"
harborUsername: "admin"
harborPassword: "${HARBOR_ADMIN_PASSWORD}"
umaClientSecretName: "resman-client"
umaClientSecretNamespace: ${NAMESPACE}
authServerIp: ${public_ip}
authServerHostname: "auth"
clusterIssuer: ${TLS_CLUSTER_ISSUER}
resourceCatalogVolumeStorageType: standard
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
      --version 1.1.5
  fi
}

main "$@"
