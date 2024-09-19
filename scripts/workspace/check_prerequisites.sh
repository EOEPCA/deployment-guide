#!/bin/bash

echo "Checking prerequisites for deploying the Workspace..."

source ../common/utils.sh

# Check for kubectl
if command_exists kubectl; then
  echo "kubectl is installed."
  # Check if kubectl can connect to your cluster
  check_kubectl_connection
else
  echo "kubectl is not installed. Please install kubectl."
  exit 1
fi

# Check for Helm
if command_exists helm; then
  echo "Helm is installed."
  # Check Helm version
  check_helm_version
else
  echo "Helm is not installed. Please install Helm."
  exit 1
fi

# Check for Git
if command_exists git; then
  echo "Git is installed."
else
  echo "Git is not installed. Please install Git."
  exit 1
fi

# # Check for Cert-Manager
# if kubectl get pods --all-namespaces | grep -i cert-manager >/dev/null 2>&1; then
#   echo "Cert-Manager is installed."
# else
#   echo "Cert-Manager is not installed. Please install Cert-Manager."
#   exit 1
# fi

# # Check for Ingress Controller
# if kubectl get pods --all-namespaces | grep -i ingress-controller >/dev/null 2>&1; then
#   echo "Ingress Controller is installed."
# else
#   echo "Ingress Controller is not installed. Please install an Ingress Controller (e.g., NGINX Ingress Controller)."
#   exit 1
# fi

# Optional check for Python or python3
if command_exists python || command_exists python3; then
  echo "Python is installed."
else
  echo "Python is not installed, which is optional but recommended for certain scripts."
fi

echo -e "\nAll prerequisite checks passed successfully. ✅"