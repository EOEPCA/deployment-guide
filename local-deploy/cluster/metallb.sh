#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

public_ip="${1:-192.168.49.123}"

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

echo -e "\nDeploy the metallb Load Balancer with public_ip=${public_ip}..."
values | helm upgrade --install metallb metallb -f - \
  --repo https://metallb.github.io/metallb \
  --namespace metallb-system --create-namespace
