#!/bin/bash

source ../common/utils.sh
source ../common/validation-utils.sh
source ~/.eoepca/state

check_pods_running "application-quality" "app.kubernetes.io/component=api" 1
check_pods_running "application-quality" "app=application-quality-db" 1
check_pods_running "application-quality" "app.kubernetes.io/component=web" 1

check_service_exists "application-quality" "application-quality-api"
check_service_exists "application-quality" "application-quality-db"
check_service_exists "application-quality" "application-quality-web"

check_url_status_code "${HTTP_SCHEME}://${APP_QUALITY_PUBLIC_HOST}" "200"

if [ "${APP_QUALITY_ENABLE_SONARQUBE:-false}" = "true" ]; then
    check_pods_running "application-quality-sonarqube" "app.kubernetes.io/name=postgresql" 1
    check_service_exists "application-quality-sonarqube" "application-quality-sonarqube-db"
    check_service_exists "application-quality-sonarqube" "application-quality-sonarqube-sonarqube"

    if [ "${INGRESS_CLASS:-}" = "apisix" ]; then
        kubectl get apisixroute application-quality-sonarqube-route -n application-quality-sonarqube
        check_url_status_code "${HTTP_SCHEME}://${APP_QUALITY_PUBLIC_HOST}/sonarqube" "200"
    fi
fi

echo
echo "All resources in application-quality namespace:"
kubectl get all -n application-quality

if [ "${APP_QUALITY_ENABLE_SONARQUBE:-false}" = "true" ]; then
    echo
    echo "All resources in application-quality-sonarqube namespace:"
    kubectl get all -n application-quality-sonarqube
fi