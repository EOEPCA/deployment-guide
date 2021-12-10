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

values() {
  # If no ClusterIssuer then turn off ssl-redirect
  if [ "${USE_TLS}" = "false" ]; then
  cat - <<EOF
controller:
  config:
    ssl-redirect: false
EOF
  fi
}

# Install with helm
if [ "${USE_INGRESS_NGINX_HELM}" = "true" ]; then
  echo -e "\nIngress-nginx..."
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace ingress-nginx uninstall ingress-nginx
  else
    values | helm ${ACTION_HELM} ingress-nginx ingress-nginx -f - \
      --repo https://kubernetes.github.io/ingress-nginx \
      --namespace ingress-nginx --create-namespace \
      --version='<4'
  fi
# Install with minikube addon
else
  # enable addon
  echo "Enable Nginx ingress controller..."
  minikube addons enable ingress
  echo "  [done]"

  # patch service type to LoadBalancer
  if [ "${USE_INGRESS_NGINX_LOADBALANCER}" = "true" ]; then
    echo "Patch ingress controller service type to LoadBalancer"
    kubectl -n ingress-nginx patch svc/ingress-nginx-controller -p '{"spec":{"type":"LoadBalancer"}}'
    echo "  [done]"
  fi
fi
