#!/bin/bash

source ../common/utils.sh
source "$HOME/.eoepca/state"

echo "Applying Kubernetes secrets..."
kubectl create namespace resource-registration --dry-run=client -o yaml | kubectl apply -f -

create_secret() {
  local secret_name="$1"
  local args=()

  if [[ "$secret_name" == "registration-harvester-secret" ]]; then
    # Consumed both by the harvester worker pods (envFrom) and by the
    # Operaton chart's postgres subchart (database.credentialsSecretName).
    args+=(--from-literal="OPERATON_DB_USERNAME=operaton")
    args+=(--from-literal="OPERATON_DB_PASSWORD=$OPERATON_DB_PASSWORD")
  fi

  if [[ "${ENABLE_USGS_M2M:-no}" == "yes" ]]; then
    args+=(--from-literal="EODAG__USGS__API__CREDENTIALS__USERNAME=$USGS_M2M_USERNAME")
    args+=(--from-literal="EODAG__USGS__API__CREDENTIALS__PASSWORD=$USGS_M2M_PASSWORD")
  fi

  if [[ "${ENABLE_CDSE_CREDENTIALS:-no}" == "yes" ]]; then
    args+=(--from-literal="EODAG__COP_DATASPACE__AUTH__CREDENTIALS__USERNAME=$CDSE_USERNAME")
    args+=(--from-literal="EODAG__COP_DATASPACE__AUTH__CREDENTIALS__PASSWORD=$CDSE_PASSWORD")
  fi

  if [[ "${RESOURCE_REGISTRATION_PROTECTED_TARGETS:-no}" == "yes" ]]; then
    if [[ "$secret_name" == "registration-api-secret" ]]; then
      args+=(--from-literal="EOEPCA_REGISTRATION_API_IAM_CLIENT_ID=$RESOURCE_REGISTRATION_IAM_CLIENT_ID")
      args+=(--from-literal="EOEPCA_REGISTRATION_API_IAM_CLIENT_SECRET=$RESOURCE_REGISTRATION_IAM_CLIENT_SECRET")
    fi

    if [[ "$secret_name" == "registration-harvester-secret" ]]; then
      args+=(--from-literal="IAM_CLIENT_ID=$RESOURCE_REGISTRATION_IAM_CLIENT_ID")
      args+=(--from-literal="IAM_CLIENT_SECRET=$RESOURCE_REGISTRATION_IAM_CLIENT_SECRET")
    fi
  fi

  kubectl create secret generic "$secret_name" "${args[@]}" \
    --namespace resource-registration \
    --dry-run=client -o yaml | kubectl apply -f -
}

# Create both secrets with identical content
create_secret "registration-api-secret"
create_secret "registration-harvester-secret"

echo "✅ Secrets applied."
