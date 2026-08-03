#!/bin/bash

# Load utility functions
source ../common/utils.sh
echo "Configuring the Operations BB..."

# ---------- Core configuration ----------
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for persistent data (ReadWriteOnce)" "standard" is_non_empty
configure_cert

# ---------- Prometheus sizing ----------
ask "PROMETHEUS_STORAGE_SIZE" "Storage size for Prometheus TSDB" "50Gi" is_non_empty
ask "PROMETHEUS_RETENTION" "Metrics retention period (e.g. 30d, 90d)" "30d" is_non_empty

# ---------- Loki / S3 ----------
ask "S3_HOST" "Host URL for the S3-compatible object store (e.g. minio.example.com)" "" is_non_empty
ask "S3_BUCKET" "Bucket name for Loki chunk storage" "logging" is_non_empty
ask "S3_ACCESS_KEY" "Access key for S3 storage" "" is_non_empty
ask "S3_SECRET_KEY" "Secret key for S3 storage" "" is_non_empty
ask "LOKI_RETENTION_HOURS" "Log retention period in hours" "168" is_non_empty

# ---------- IAM ----------
ask "OPERATIONS_ENABLE_IAM" "Enable IAM/Keycloak integration? (yes/no)" "no" is_non_empty

if [ "${OPERATIONS_ENABLE_IAM}" = "yes" ]; then
    ask "KEYCLOAK_HOST" "Keycloak service hostname (e.g. iam-auth.example.com)" "" is_non_empty
    ask "REALM" "Keycloak realm name" "eoepca" is_non_empty
    ask "GRAFANA_CLIENT_ID" "OIDC client ID for Grafana" "monitoring" is_non_empty
    ask "KEEP_CLIENT_ID" "OIDC client ID for Keep" "alerting" is_non_empty
fi

# ---------- Optional STAC alerts ----------
ask "OPERATIONS_ENABLE_STAC_ALERTS" "Deploy STAC-specific SLO alerts? (yes/no)" "no" is_non_empty

# ---------- Generate a cookie secret for oauth2-proxy ----------
if [ -z "${OAUTH2_PROXY_COOKIE_SECRET:-}" ]; then
    add_to_state_file "OAUTH2_PROXY_COOKIE_SECRET" "$(generate_aes_key 32)"
fi

# ---------- Template: kube-prometheus-stack ----------
TEMPLATE_PATH="kube-prometheus-stack/values-template.yaml"
OUTPUT_PATH="kube-prometheus-stack/generated-values.yaml"
gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"

# ---------- Template: loki ----------
TEMPLATE_PATH="loki/values-template.yaml"
OUTPUT_PATH="loki/generated-values.yaml"
gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"

# ---------- Template: keep + oauth2-proxy ----------
TEMPLATE_PATH="keep/values-template.yaml"
OUTPUT_PATH="keep/generated-values.yaml"
gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"

TEMPLATE_PATH="keep/oauth2-proxy-values-template.yaml"
OUTPUT_PATH="keep/generated-oauth2-proxy-values.yaml"
gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"

# ---------- Template: AlertmanagerConfig ----------
TEMPLATE_PATH="alerting/alertmanagerconfig-template.yaml"
OUTPUT_PATH="alerting/generated-alertmanagerconfig.yaml"
gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"

TEMPLATE_PATH="alerting/keep-alertmanager-relay-template.yaml"
OUTPUT_PATH="alerting/generated-keep-alertmanager-relay.yaml"
gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"

# ---------- Template: IAM (if enabled) ----------
if [ "${OPERATIONS_ENABLE_IAM}" = "yes" ]; then
    TEMPLATE_PATH="iam/iam-template.yaml"
    OUTPUT_PATH="iam/generated-iam.yaml"
    gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"
    echo "✅ Configuration file generated: $OUTPUT_PATH"
fi

# ---------- Template: Ingress ----------
for svc in monitoring alerting; do
    if [ "$INGRESS_CLASS" = "apisix" ]; then
        INGRESS_TEMPLATE_PATH="ingress/${svc}-ingress-template.yaml"
    elif [ "$INGRESS_CLASS" = "nginx" ]; then
        INGRESS_TEMPLATE_PATH="ingress/${svc}-nginx-ingress-template.yaml"
    fi
    INGRESS_OUTPUT_PATH="ingress/generated-${svc}-ingress.yaml"
    gomplate -f "$INGRESS_TEMPLATE_PATH" -o "$INGRESS_OUTPUT_PATH" \
        --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
    echo "✅ Configuration file generated: $INGRESS_OUTPUT_PATH"
done

echo "✅ Operations BB configuration complete."