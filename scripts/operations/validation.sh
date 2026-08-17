#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "${HOME}/.eoepca/state"

NAMESPACE="operations"

check_deployment_ready "${NAMESPACE}" "kube-prometheus-stack-operator"
check_deployment_ready "${NAMESPACE}" "kube-prometheus-stack-grafana"
check_deployment_ready "${NAMESPACE}" "kube-prometheus-stack-kube-state-metrics"
check_pods_running "${NAMESPACE}" "app.kubernetes.io/name=prometheus" 1
check_pods_running "${NAMESPACE}" "app.kubernetes.io/name=alertmanager" 1

check_pods_running "${NAMESPACE}" "app.kubernetes.io/name=loki" 1
check_service_exists "${NAMESPACE}" "loki-gateway"

check_pods_running "${NAMESPACE}" "app.kubernetes.io/name=alloy-logs" 1
check_service_exists "${NAMESPACE}" "alloy-logs"

check_deployment_ready "${NAMESPACE}" "keep-backend"
check_deployment_ready "${NAMESPACE}" "keep-frontend"
check_deployment_ready "${NAMESPACE}" "keep-alertmanager-relay"
if [ "${OPERATIONS_ENABLE_IAM}" = "yes" ]; then
  check_deployment_ready "${NAMESPACE}" "keep-oauth2-proxy"
fi

check_secret_exists "${NAMESPACE}" "loki-s3-credentials"
if [ "${OPERATIONS_ENABLE_IAM}" = "yes" ]; then
  check_secret_exists "${NAMESPACE}" "keep-oauth2-proxy-cookie"
fi

check_pvc_bound "${NAMESPACE}" "prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0"

check_url_status_code "$HTTP_SCHEME://monitoring.$INGRESS_HOST" "200"
check_url_status_code "$HTTP_SCHEME://alerting.$INGRESS_HOST" "200"

check_crd_exists "servicemonitors.monitoring.coreos.com"
check_crd_exists "prometheusrules.monitoring.coreos.com"
check_crd_exists "alertmanagerconfigs.monitoring.coreos.com"

echo
echo "All Resources:"
echo
kubectl get all -n "${NAMESPACE}"
