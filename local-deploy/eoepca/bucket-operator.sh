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
  helmChart
  openstackSecret
}

# Secret for openstack access
openstackSecret() {
  kubectl -n rm create secret generic openstack \
    --from-literal=username="${OS_USERNAME}" \
    --from-literal=password="${OS_PASSWORD}" \
    --from-literal=domain="${OS_DOMAINNAME}" \
    --dry-run=client -oyaml | kubectl ${ACTION_KUBECTL} -f -
}

# Values for helm chart
values() {
  cat - <<EOF
domain: ${domain}
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
      --version 0.9.6
  fi
}

main "$@"
