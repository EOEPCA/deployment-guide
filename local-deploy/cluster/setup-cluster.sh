#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

#-------------------------------------------------------------------------------
# create cluster
#-------------------------------------------------------------------------------
echo "Create minikube cluster..."
minikube -p eoepca start --cpus max --memory max --kubernetes-version v1.21.5
minikube profile eoepca
echo "  [done]"

#-------------------------------------------------------------------------------
# metalb Load Balancer
#-------------------------------------------------------------------------------
#
# enable addon
echo "Enable metallb Load Balancer..."
minikube addons enable metallb
echo "  [done]"
#
# configure
minikube_ip="$(minikube ip)"
base_ip="$(echo -n $minikube_ip | cut -d. -f-3)"
public_ip="${base_ip}.123"
echo "Configure Load Balancer public ip = ${public_ip}"
cat - <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - ${public_ip}-${public_ip}
EOF
echo "  [done]"
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# nginx ingress controller
#-------------------------------------------------------------------------------
#
# enable addon
echo "Enable Nginx ingress controller..."
minikube addons enable ingress
echo "  [done]"
#
# patch service type to LoadBalancer
echo "Patch ingress controller service type to LoadBalancer"
kubectl -n ingress-nginx patch svc/ingress-nginx-controller -p '{"spec":{"type":"LoadBalancer"}}'
echo "  [done]"
