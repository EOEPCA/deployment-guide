#!/bin/bash

source ../common/utils.sh
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."
kubectl create namespace resource-registration --dry-run=client -o yaml | kubectl apply -f -

# ask if they want to enable USGS credentials for Landsat Harvesting
read -p "Do you want to enable USGS credentials for Landsat Harvesting? (y/n): " enable_m2m
if [[ "$enable_m2m" == "y" || "$enable_m2m" == "Y" ]]; then
  read -p "Enter USGS Username: " m2m_user
  read -s -p "Enter USGS Password: " m2m_password
  echo
  export EODAG__USGS__API__CREDENTIALS__USERNAME="$m2m_user"
  export EODAG__USGS__API__CREDENTIALS__PASSWORD="$m2m_password"
fi

# ask if they want to enable CDSE credentials for Sentinel Harvesting
read -p "Do you want to enable Copernicus Data Space Ecosystem (CDSE) credentials for Sentinel Harvesting? (y/n): " enable_cdse
if [[ "$enable_cdse" == "y" || "$enable_cdse" == "Y" ]]; then
  read -p "Enter CDSE Username: " cdse_user
  read -s -p "Enter CDSE Password: " cdse_password
  echo
  export EODAG__COP_DATASPACE__AUTH__CREDENTIALS__USERNAME="$cdse_user"
  export EODAG__COP_DATASPACE__AUTH__CREDENTIALS__PASSWORD="$cdse_password"
fi

# Build kubectl command dynamically for both secrets
create_secret() {
  local secret_name="$1"
  
  kubectl_cmd="kubectl create secret generic $secret_name"

  if [[ "$secret_name" == "registration-harvester-secret" ]]; then
    # Consumed both by the harvester worker pods (envFrom) and by the
    # Operaton chart's postgres subchart (database.credentialsSecretName).
    kubectl_cmd="$kubectl_cmd --from-literal=OPERATON_DB_USERNAME=\"operaton\""
    kubectl_cmd="$kubectl_cmd --from-literal=OPERATON_DB_PASSWORD=\"$OPERATON_DB_PASSWORD\""
  fi

  if [[ "$enable_m2m" == "y" || "$enable_m2m" == "Y" ]]; then
    kubectl_cmd="$kubectl_cmd --from-literal=EODAG__USGS__API__CREDENTIALS__USERNAME=\"$EODAG__USGS__API__CREDENTIALS__USERNAME\""
    kubectl_cmd="$kubectl_cmd --from-literal=EODAG__USGS__API__CREDENTIALS__PASSWORD=\"$EODAG__USGS__API__CREDENTIALS__PASSWORD\""
  fi

  if [[ "$enable_cdse" == "y" || "$enable_cdse" == "Y" ]]; then
    kubectl_cmd="$kubectl_cmd --from-literal=EODAG__COP_DATASPACE__AUTH__CREDENTIALS__USERNAME=\"$EODAG__COP_DATASPACE__AUTH__CREDENTIALS__USERNAME\""
    kubectl_cmd="$kubectl_cmd --from-literal=EODAG__COP_DATASPACE__AUTH__CREDENTIALS__PASSWORD=\"$EODAG__COP_DATASPACE__AUTH__CREDENTIALS__PASSWORD\""
  fi

  if [[ "${RESOURCE_REGISTRATION_PROTECTED_TARGETS:-no}" == "yes" ]]; then
    if [[ "$secret_name" == "registration-api-secret" ]]; then
      kubectl_cmd="$kubectl_cmd --from-literal=EOEPCA_REGISTRATION_API_IAM_CLIENT_ID=\"$RESOURCE_REGISTRATION_IAM_CLIENT_ID\""
      kubectl_cmd="$kubectl_cmd --from-literal=EOEPCA_REGISTRATION_API_IAM_CLIENT_SECRET=\"$RESOURCE_REGISTRATION_IAM_CLIENT_SECRET\""
    fi

    if [[ "$secret_name" == "registration-harvester-secret" ]]; then
      kubectl_cmd="$kubectl_cmd --from-literal=IAM_CLIENT_ID=\"$RESOURCE_REGISTRATION_IAM_CLIENT_ID\""
      kubectl_cmd="$kubectl_cmd --from-literal=IAM_CLIENT_SECRET=\"$RESOURCE_REGISTRATION_IAM_CLIENT_SECRET\""
    fi
  fi
  kubectl_cmd="$kubectl_cmd --namespace resource-registration"
  kubectl_cmd="$kubectl_cmd --dry-run=client -o yaml | kubectl apply -f -"

  eval "$kubectl_cmd"
}

# Create both secrets with identical content
create_secret "registration-api-secret"
create_secret "registration-harvester-secret"

echo "✅ Secrets applied."
