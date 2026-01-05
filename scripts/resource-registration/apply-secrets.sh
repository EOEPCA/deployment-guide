#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."
kubectl create namespace resource-registration --dry-run=client -o yaml | kubectl apply -f -

# Create secrets for Flowable
kubectl create secret generic flowable-admin-credentials \
  --from-literal=FLOWABLE_ADMIN_USER="$FLOWABLE_ADMIN_USER" \
  --from-literal=FLOWABLE_ADMIN_PASSWORD="$FLOWABLE_ADMIN_PASSWORD" \
  --namespace resource-registration \
  --dry-run=client -o yaml | kubectl apply -f -

# ask if they want to enable USGS M2M for Landsat Harvesting
read -p "Do you want to enable USGS M2M credentials for Landsat Harvesting? (y/n): " enable_m2m
if [[ "$enable_m2m" == "y" || "$enable_m2m" == "Y" ]]; then
  read -p "Enter USGS M2M Username: " m2m_user
  read -s -p "Enter USGS M2M Password: " m2m_password
  echo
  export M2M_USER="$m2m_user"
  export M2M_PASSWORD="$m2m_password"
fi

# ask if they want to enable CDSE credentials for Sentinel Harvesting
read -p "Do you want to enable Copernicus Data Space Ecosystem (CDSE) credentials for Sentinel Harvesting? (y/n): " enable_cdse
if [[ "$enable_cdse" == "y" || "$enable_cdse" == "Y" ]]; then
  read -p "Enter CDSE Username: " cdse_user
  read -p "Enter CDSE Password: " cdse_password
  echo
  export CDSE_USER="$cdse_user"
  export CDSE_PASSWORD="$cdse_password"
fi

# Build kubectl command dynamically for both secrets
create_secret() {
  local secret_name="$1"
  
  kubectl_cmd="kubectl create secret generic $secret_name"
  kubectl_cmd="$kubectl_cmd --from-literal=FLOWABLE_USER=\"$FLOWABLE_ADMIN_USER\""
  kubectl_cmd="$kubectl_cmd --from-literal=FLOWABLE_PASSWORD=\"$FLOWABLE_ADMIN_PASSWORD\""

  if [[ "$enable_m2m" == "y" || "$enable_m2m" == "Y" ]]; then
    kubectl_cmd="$kubectl_cmd --from-literal=M2M_USER=\"$M2M_USER\""
    kubectl_cmd="$kubectl_cmd --from-literal=M2M_PASSWORD=\"$M2M_PASSWORD\""
  fi

  if [[ "$enable_cdse" == "y" || "$enable_cdse" == "Y" ]]; then
    kubectl_cmd="$kubectl_cmd --from-literal=CDSE_USER=\"$CDSE_USER\""
    kubectl_cmd="$kubectl_cmd --from-literal=CDSE_PASSWORD=\"$CDSE_PASSWORD\""
  fi

  if [[ "$RESOURCE_REGISTRATION_PROTECTED_TARGETS" == "yes" ]]; then
    kubectl_cmd="$kubectl_cmd --from-literal=IAM_CLIENT_ID=\"$RESOURCE_REGISTRATION_IAM_CLIENT_ID\""
    kubectl_cmd="$kubectl_cmd --from-literal=IAM_CLIENT_SECRET=\"$RESOURCE_REGISTRATION_IAM_CLIENT_SECRET\""
  fi

  kubectl_cmd="$kubectl_cmd --namespace resource-registration"
  kubectl_cmd="$kubectl_cmd --dry-run=client -o yaml | kubectl apply -f -"

  eval "$kubectl_cmd"
}

# Create both secrets with identical content
create_secret "registration-api-secret"
create_secret "registration-harvester-secret"

echo "✅ Secrets applied."
