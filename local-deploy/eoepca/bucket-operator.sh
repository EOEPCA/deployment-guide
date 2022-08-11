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

main() {
  if [ "${OS_DOMAINNAME}" != "cloud_XXXXX" ]; then
    helmChart
    openstackSecret
  else
    echo "SKIPPING bucket operator deployment - openstack credentials have not been configured"
  fi
}

# Secret for openstack access
openstackSecret() {
  kubectl -n rm create secret generic openstack \
    --from-literal=username="${OS_USERNAME}" \
    --from-literal=password="${OS_PASSWORD}" \
    --from-literal=domainname="${OS_DOMAINNAME}" \
    --dry-run=client -oyaml | kubectl ${ACTION_KUBECTL} -f -
}

# Values for helm chart
values() {
  cat - <<EOF
domain: ${domain}
data:
  OS_MEMBERROLEID: "${OS_MEMBERROLEID}"
  OS_SERVICEPROJECTID: "${OS_SERVICEPROJECTID}"
  USER_EMAIL_PATTERN: "${USER_EMAIL_PATTERN}"
ingress:
  annotations:
    cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
EOF
}

# Helm chart
helmChart() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall bucket-operator
  else
    values | helm ${ACTION_HELM} bucket-operator rm-bucket-operator -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 0.9.9
  fi
}

main "$@"
