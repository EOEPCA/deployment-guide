#!/bin/bash

source ../common/utils.sh
echo "Configuring the Operations BB..."

ask "PROMETHEUS_STORAGE_SIZE" "Storage size for Prometheus TSDB" "50Gi" is_non_empty
ask "PROMETHEUS_RETENTION" "Metrics retention period (e.g. 30d, 90d)" "30d" is_non_empty

ask "S3_HOST" "Host URL for the S3-compatible object store (e.g. minio.example.com)" "" is_non_empty
ask "S3_BUCKET" "Bucket name for Loki chunk storage" "logging" is_non_empty
ask "S3_ACCESS_KEY" "Access key for S3 storage" "" is_non_empty
ask "S3_SECRET_KEY" "Secret key for S3 storage" "" is_non_empty
ask "LOKI_RETENTION_HOURS" "Log retention period in hours" "168" is_non_empty

ask "OPERATIONS_ENABLE_IAM" "Enable IAM/Keycloak integration? (yes/no)" "no" is_non_empty

if [ "${OPERATIONS_ENABLE_IAM}" = "yes" ]; then
    ask "KEYCLOAK_HOST" "Keycloak service hostname (e.g. iam-auth.example.com)" "" is_non_empty
    ask "REALM" "Keycloak realm name" "eoepca" is_non_empty

    ask "GRAFANA_CLIENT_ID" "OIDC client ID for Grafana" "monitoring" is_non_empty
    if [ -z "$GRAFANA_CLIENT_SECRET" ]; then
        GRAFANA_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "GRAFANA_CLIENT_SECRET" "$GRAFANA_CLIENT_SECRET"
    fi

    ask "KEEP_CLIENT_ID" "OIDC client ID for Keep" "alerting" is_non_empty
    if [ -z "$KEEP_CLIENT_SECRET" ]; then
        KEEP_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "KEEP_CLIENT_SECRET" "$KEEP_CLIENT_SECRET"
    fi
fi

ask "OPERATIONS_ENABLE_STAC_ALERTS" "Deploy STAC-specific SLO alerts? (yes/no)" "no" is_non_empty

if [ -z "${OAUTH2_PROXY_COOKIE_SECRET:-}" ]; then
    add_to_state_file "OAUTH2_PROXY_COOKIE_SECRET" "$(generate_aes_key 32)"
fi

gomplate -f "kube-prometheus-stack/values-template.yaml" -o "kube-prometheus-stack/generated-values.yaml"
gomplate -f "loki/values-template.yaml" -o "loki/generated-values.yaml"
gomplate -f "keep/values-template.yaml" -o "keep/generated-values.yaml"
gomplate -f "keep/oauth2-proxy-values-template.yaml" -o "keep/generated-oauth2-proxy-values.yaml"
gomplate -f "alerting/alertmanagerconfig-template.yaml" -o "alerting/generated-alertmanagerconfig.yaml"
gomplate -f "alerting/keep-alertmanager-relay-template.yaml" -o "alerting/generated-keep-alertmanager-relay.yaml"

if [ "${OPERATIONS_ENABLE_IAM}" = "yes" ]; then
    gomplate -f "iam/iam-template.yaml" -o "iam/generated-iam.yaml"
fi

for svc in monitoring alerting; do
    if [ "$INGRESS_CLASS" = "apisix" ]; then
        INGRESS_TEMPLATE_PATH="ingress/${svc}-ingress-template.yaml"
    elif [ "$INGRESS_CLASS" = "nginx" ]; then
        INGRESS_TEMPLATE_PATH="ingress/${svc}-nginx-ingress-template.yaml"
    fi
    gomplate -f "$INGRESS_TEMPLATE_PATH" -o "ingress/generated-${svc}-ingress.yaml" \
        --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
done

echo "✅ Operations BB configuration complete."
