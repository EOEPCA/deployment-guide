#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

public_ip="${1:-192.168.49.123}"
domain="${2:-${public_ip}.nip.io}"

values() {
  cat - <<EOF
volumeClaim:
  name: eoepca-userman-pvc
  create: false
config:
  domain: auth.${domain}
  volumeClaim:
    name: eoepca-userman-pvc
opendj:
  # This can be useful to workaround helm 'failed to upgrade' errors due to
  # immutable fields in the 'um-login-service-persistence-init-ss' job
  # persistence:
  #   enabled: false
  volumeClaim:
    name: eoepca-userman-pvc
oxauth:
  volumeClaim:
    name: eoepca-userman-pvc
oxtrust:
  volumeClaim:
    name: eoepca-userman-pvc
global:
  domain: auth.${domain}
  nginxIp: ${public_ip}
nginx:
  ingress:
    # annotations:
    #   cert-manager.io/cluster-issuer: letsencrypt-staging
    # hosts:
    #   - auth.${domain}
    # tls:
    #   - hosts:
    #       - auth.${domain}
    #     secretName: login-service-tls
    enabled: true
    annotations: {}
      # kubernetes.io/ingress.class: nginx
      # kubernetes.io/tls-acme: "true"
    path: /
    hosts:
      - auth.${domain}
    tls: 
    - secretName: tls-certificate
      hosts:
        - auth.${domain}
EOF
}

values | helm upgrade --install um-login-service login-service -f - \
  --repo https://eoepca.github.io/helm-charts \
  --namespace default --create-namespace \
  --version 0.9.45
