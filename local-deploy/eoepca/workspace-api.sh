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

values() {
  cat - <<EOF
fullnameOverride: workspace-api
ingress:
  enabled: false
  # hosts:
  #   - host: workspace-api.${domain}
  #     paths: ["/"]
  # tls:
  #   - hosts:
  #       - workspace-api.${domain}
  #     secretName: workspace-api-tls
prefixForName: "guide-user"
helmChartStorageClassName: "standard"
s3Endpoint: "https://cf2.cloudferro.com:8080"
s3Region: "RegionOne"
workspaceDomain: ${domain}
harborUrl: "https://harbor.${domain}"
harborUsername: "admin"
harborPassword: "${HARBOR_ADMIN_PASSWORD}"
umaClientSecretName: "resman-client"
umaClientSecretNamespace: "rm"
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace rm uninstall workspace-api
else
  values | helm ${ACTION_HELM} workspace-api rm-workspace-api -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace rm --create-namespace \
    --version 1.0.10
fi
