#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

values() {
  cat - <<EOF
configInline:
  address-pools:
    - name: default
      protocol: layer2
      addresses:
        - 192.168.49.123/32
EOF
}

values | helm upgrade -i metallb metallb/metallb -f - \
  --repo https://metallb.github.io/metallb \
  --namespace metallb-system --create-namespace
