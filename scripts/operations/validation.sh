#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
source "${HOME}/.eoepca/state"

NAMESPACE="operations"

# kube-prometheus-stack
check_deployment_ready "${NAMESPACE}" "kube-prometheus-stack-operator"
check_deployment_ready "${NAMESPACE}" "kube-prometheus-stack-grafana"
check_deployment_ready "${NAMESPACE}" "kube-prometheus-stack-kube-state-metrics"
check_pods_running "${NAMESPACE}" "app.kubernetes.io/name=prometheus" 1
check_pods_running "${NAMESPACE}" "app.kubernetes.io/name=alertmanager" 1

# Loki
check_pods_running "${NAMESPACE}" "app.kubernetes.io/name=loki" 1
check_service_exists "${NAMESPACE}" "loki-gateway"

# Alloy
check_pods_running "${NAMESPACE}" "app.kubernetes.io/name=alloy-logs" 1
check_service_exists "${NAMESPACE}" "alloy-logs"

# Keep + oauth2-proxy
check_deployment_ready "${NAMESPACE}" "keep-backend"
check_deployment_ready "${NAMESPACE}" "keep-frontend"
check_deployment_ready "${NAMESPACE}" "keep-alertmanager-relay"
if [ "${OPERATIONS_ENABLE_IAM}" = "yes" ]; then
  check_deployment_ready "${NAMESPACE}" "keep-oauth2-proxy"
fi

# Secrets
check_secret_exists "${NAMESPACE}" "loki-s3-credentials"
if [ "${OPERATIONS_ENABLE_IAM}" = "yes" ]; then
  check_secret_exists "${NAMESPACE}" "keep-oauth2-proxy-cookie"
fi

# Storage
check_pvc_bound "${NAMESPACE}" "prometheus-kube-prometheus-stack-prometheus-db-prometheus-kube-prometheus-stack-prometheus-0"

# URL reachability
check_url_status_code "$HTTP_SCHEME://monitoring.$INGRESS_HOST" "200"
check_url_status_code "$HTTP_SCHEME://alerting.$INGRESS_HOST" "200"

# CRDs installed
check_crd_exists "servicemonitors.monitoring.coreos.com"
check_crd_exists "prometheusrules.monitoring.coreos.com"
check_crd_exists "alertmanagerconfigs.monitoring.coreos.com"

echo
echo "All Resources:"
echo
kubectl get all -n "${NAMESPACE}"

# Advanced Checks
read -p "Run advanced checks? These exercise end-to-end alert flow and may take ~2 min (yes/no): " RUN_ADVANCED

if [ "${RUN_ADVANCED}" = "yes" ]; then
  echo
  echo "Running advanced checks..."
  echo

  # Helper — run curl from inside the Grafana pod (which has curl available
  # and can resolve in-cluster service DNS).
  cluster_curl() {
    kubectl -n "${NAMESPACE}" exec deploy/kube-prometheus-stack-grafana -c grafana -- \
      curl -s --max-time 10 "$@" 2>/dev/null
  }

  # 1. Prometheus is scraping its expected targets
  echo "▶ Checking Prometheus scrape targets..."
  TARGETS=$(cluster_curl "http://kube-prometheus-stack-prometheus.${NAMESPACE}.svc:9090/api/v1/targets")
  ACTIVE=$(echo "${TARGETS}" | grep -o '"health":"up"' | wc -l)
  DOWN=$(echo "${TARGETS}" | grep -o '"health":"down"' | wc -l)
  echo "  ${ACTIVE} targets up, ${DOWN} down"
  if [ "${DOWN}" -gt 0 ]; then
    echo "  ⚠️  Some scrape targets are down — check Grafana → Status → Targets"
  fi

  # 2. Alertmanager has the Keep receiver loaded
  echo "▶ Checking Alertmanager configuration..."
  AM_STATUS=$(cluster_curl "http://kube-prometheus-stack-alertmanager.${NAMESPACE}.svc:9093/api/v2/status")
  if echo "${AM_STATUS}" | grep -q "keep"; then
    echo "  ✅ Keep receiver is configured"
  else
    echo "  ❌ Keep receiver missing from Alertmanager config"
  fi

  # 3. Watchdog alert is firing (it's always-on by design)
  echo "▶ Checking Watchdog alert is firing..."
  AM_ALERTS=$(cluster_curl "http://kube-prometheus-stack-alertmanager.${NAMESPACE}.svc:9093/api/v2/alerts")
  if echo "${AM_ALERTS}" | grep -q "Watchdog"; then
    echo "  ✅ Watchdog alert is active in Alertmanager"
  else
    echo "  ⚠️  Watchdog not found — alert rules may not have loaded yet (give it 1-2 min)"
  fi

  # 4. Loki is accepting writes from Alloy
  echo "▶ Checking Loki has received logs from Alloy..."
  LOKI_LABELS=$(cluster_curl "http://loki-gateway.${NAMESPACE}.svc/loki/api/v1/labels")
  LABEL_COUNT=$(echo "${LOKI_LABELS}" | grep -o '"[a-z_]\+"' | wc -l)
  if [ "${LABEL_COUNT}" -gt 1 ]; then
    echo "  ✅ Loki has labels (${LABEL_COUNT}) — receiving logs"
  else
    echo "  ❌ Loki has no labels — Alloy may not be shipping logs"
  fi

  # 5. Grafana datasources are healthy
  echo "▶ Checking Grafana datasources..."
  GRAFANA_PWD=$(kubectl -n "${NAMESPACE}" get secret kube-prometheus-stack-grafana \
    -o jsonpath='{.data.admin-password}' | base64 -d)
  DS_STATUS=$(cluster_curl -u "admin:${GRAFANA_PWD}" \
    "http://localhost:3000/api/datasources")
  if echo "${DS_STATUS}" | grep -q '"type":"prometheus"' && \
     echo "${DS_STATUS}" | grep -q '"type":"loki"'; then
    echo "  ✅ Both Prometheus and Loki datasources are present"
  else
    echo "  ❌ Datasources missing from Grafana"
  fi

  # 6. Keep is reachable end-to-end through the ingress
  echo "▶ Checking Keep API through ingress..."
  KEEP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "x-api-key: validation" \
    "${HTTP_SCHEME}://alerting.${INGRESS_HOST}/v2/alerts" \
    --max-time 10 || echo "000")
  if [ "${KEEP_STATUS}" = "200" ]; then
    echo "  ✅ Keep API responding (HTTP ${KEEP_STATUS})"
  else
    echo "  ⚠️  Keep API returned HTTP ${KEEP_STATUS} — check ingress routing"
  fi

  # 7. Watchdog alert has reached Keep
  # Note: when AUTH_TYPE=NO_AUTH, any value in x-api-key is accepted.
  # When IAM is enabled, the API key validation requires a real key.
  echo "▶ Checking Watchdog reached Keep..."
  KEEP_ALERTS=$(curl -s -H "x-api-key: validation" \
    "${HTTP_SCHEME}://alerting.${INGRESS_HOST}/v2/alerts" \
    --max-time 10 || echo "")
  if echo "${KEEP_ALERTS}" | grep -q "Watchdog"; then
    echo "  ✅ Watchdog alert visible in Keep — end-to-end pipeline working"
  elif [ "${KEEP_ALERTS}" = "[]" ]; then
    echo "  ⚠️  Keep returned no alerts — check keep-alertmanager-relay logs and Keep backend logs"
  else
    echo "  ⚠️  Watchdog not yet in Keep — alerts may take a few minutes to propagate"
  fi

  echo
  echo "Advanced checks complete."
fi