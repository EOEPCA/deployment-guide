#!/bin/bash

source ../common/utils.sh
source ~/.eoepca/state

NAMESPACE="application-quality"

echo "Applying secrets to namespace: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic application-quality-auth-client \
    --from-literal=OIDC_RP_CLIENT_ID="${APP_QUALITY_CLIENT_ID:-}" \
    --from-literal=OIDC_RP_CLIENT_SECRET="${APP_QUALITY_CLIENT_SECRET:-}" \
    --namespace "${NAMESPACE}" \
    --dry-run=client -o yaml | kubectl apply -f -

if [ "${APP_QUALITY_ENABLE_GITHUB_STATUS:-false}" = "true" ]; then
    kubectl create secret generic application-quality-github-api-tokens \
        --from-literal=GITHUB_API_TOKEN="${APP_QUALITY_GITHUB_API_TOKEN}" \
        --namespace "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f -
fi

if [ "${APP_QUALITY_ENABLE_GRAFANA:-false}" = "true" ]; then
    kubectl create secret generic application-quality-grafana-dashboards-admin-creds \
        --from-literal=GRAFANA_SECURITY_ADMIN_USER="${APP_QUALITY_GRAFANA_ADMIN_USER:-admin}" \
        --from-literal=GRAFANA_SECURITY_ADMIN_PASSWORD="${APP_QUALITY_GRAFANA_ADMIN_PASSWORD:-$(generate_aes_key 32)}" \
        --namespace "${NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f -
fi

if [ "${APP_QUALITY_ENABLE_SONARQUBE:-false}" = "true" ]; then
    SONAR_NAMESPACE="application-quality-sonarqube"

    kubectl create namespace "${SONAR_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

    kubectl create secret generic application-quality-sonarqube-db-secrets \
        --from-literal=password="${APP_QUALITY_SONARQUBE_DB_PASSWORD}" \
        --from-literal=postgres-password="${APP_QUALITY_SONARQUBE_DB_POSTGRES_PASSWORD}" \
        --namespace "${SONAR_NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f -

    kubectl create secret generic application-quality-sonarqube-monitoring-passcode \
        --from-literal=passcode="${APP_QUALITY_SONARQUBE_MONITORING_PASSCODE}" \
        --namespace "${SONAR_NAMESPACE}" \
        --dry-run=client -o yaml | kubectl apply -f -
fi

echo "Secrets applied."