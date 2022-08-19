#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source functions
configureAction "$1"
initIpDefaults

public_ip="${2:-${default_public_ip}}"

values() {
  cat - <<EOF
configInline:
  address-pools:
    - name: default
      protocol: layer2
      addresses:
        - ${public_ip}/32
EOF
}

echo -e "\nMetallb Load Balancer..."
if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace metallb-system uninstall metallb
else
  echo "  public_ip=${public_ip}"
  values | helm ${ACTION_HELM} metallb metallb -f - \
    --repo https://metallb.github.io/metallb \
    --namespace metallb-system --create-namespace
fi
