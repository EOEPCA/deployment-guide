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

domain="${2:-${default_domain}}"
NAMESPACE="rm"

values() {
  cat - <<EOF
existingSecret: minio-auth
replicas: 2

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: '600'
  path: /
  hosts:
    - minio.${domain}
  tls:
    - secretName: minio-tls
      hosts:
        - minio.${domain}

consoleIngress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    nginx.ingress.kubernetes.io/ssl-redirect: "${USE_TLS}"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: '600'
  path: /
  hosts:
    - console.minio.${domain}
  tls:
  - secretName: minio-console-tls
    hosts:
      - console.minio.${domain}

resources:
  requests:
    memory: 1Gi

persistence:
  storageClass: ${MINIO_STORAGE}

buckets:
  - name: eoepca
  - name: cache-bucket
EOF
}

# Credentials - need to exist before minio install
echo -e "\nMinio credentials..."
if [ "${ACTION_HELM}" = "uninstall" ]; then
  kubectl -n "${NAMESPACE}" delete secret minio-auth
else
  kubectl create namespace "${NAMESPACE}" 2>/dev/null
  kubectl -n "${NAMESPACE}" create secret generic minio-auth \
    --from-literal=rootUser="${MINIO_ROOT_USER}" \
    --from-literal=rootPassword="${MINIO_ROOT_PASSWORD}" \
    --dry-run=client -oyaml \
    | kubectl apply -f -
fi

# Minio
echo -e "\nMinio..."
if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall minio
else
  values | helm ${ACTION_HELM} minio minio -f - \
    --repo https://charts.min.io/ \
    --namespace "${NAMESPACE}" --create-namespace \
    --wait
fi

# s3cfg
if [ "${ACTION}" = "apply" ]; then
  cat - <<EOF > s3cfg
[default]
  host_base = minio.${domain}
  host_bucket = minio.${domain}
  access_key = ${MINIO_ROOT_USER}
  secret_key = ${MINIO_ROOT_PASSWORD}
  use_https = $(if [[ "${USE_TLS}" == "true" ]]; then echo -n "True"; else echo -n "False"; fi)
EOF
elif [ "${ACTION}" = "delete" ]; then
  rm -f s3cfg
fi
