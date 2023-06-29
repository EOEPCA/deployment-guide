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
      --version='<4.5.0' # support for k8s 1.22 dropped in chart 4.5.0
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

# The first time the ingress controller starts, two Jobs create the SSL Certificate used by the admission webhook.
# For this reason, there is an initial delay of up to two minutes until it is possible to create and validate Ingress definitions.
echo "[INFO]  Wait for ingress-nginx ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s 2>/dev/null
echo "[INFO]  ...ingress-nginx READY."

# Also the ingress-nginx admission controller seems to take a while to be ready...
ingress_admission_ready_check() {
  interval=$(( 1 ))
  msgInterval=$(( 5 ))
  step=$(( msgInterval / interval ))
  count=$(( 0 ))
  status=$(( 1 ))
  while [ $status -ne 0 ]
  do
    kubectl apply -f - <<EOF 2>/dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: readycheck
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: ImplementationSpecific
        backend:
          service:
            name: readycheck
            port:
              number: 80
EOF
    status=$(( $? ))
    if [ $status -eq 0 ]; then break; fi
    test $(( count % step )) -eq 0 && echo "[INFO]  Waiting for service/ingress-nginx-controller-admission"
    sleep $interval
    count=$(( count + interval ))
  done
  kubectl delete ingress/readycheck
}
echo "[INFO]  Wait for ingress-nginx admission ready..."
ingress_admission_ready_check
echo "[INFO]  ...ingress-nginx admission READY."
