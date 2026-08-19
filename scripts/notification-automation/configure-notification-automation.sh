#!/bin/bash

source ../common/utils.sh
echo "Configuring the Notification and Automation Building Block..."

if [ "${INGRESS_CLASS}" != "apisix" ]; then
    echo "❌ Notification and Automation currently requires INGRESS_CLASS=apisix."
    echo "   The wildcard ingress route is generated as an ApisixRoute/ApisixTls; there is no nginx equivalent yet."
    exit 1
fi

ask "DNS_CLUSTER_ISSUER" "Cert-manager ClusterIssuer supporting DNS-01 (needed for wildcard certs)" "letsencrypt-dns01"

ask "NA_ENABLE_OIDC" "Enable OIDC authentication on eventing resources? (yes/no)" "no" is_yes_no
if [ "$NA_ENABLE_OIDC" = "yes" ]; then
    echo "Note: OIDC requires the Identity BB (Keycloak) to be reachable from the cluster."
    echo "      You will need to configure realm and client details separately."
fi

if [ -z "$NA_GITHUB_WEBHOOK_SECRET" ]; then
    NA_GITHUB_WEBHOOK_SECRET=$(openssl rand -hex 24)
    add_to_state_file "NA_GITHUB_WEBHOOK_SECRET" "$NA_GITHUB_WEBHOOK_SECRET"
    echo "Generated a random GitHub webhook secret and stored it in ~/.eoepca/state."
fi

ask "NA_ENABLE_EMAILER" "Enable the emailer sink? (yes/no)" "no" is_yes_no
if [ "$NA_ENABLE_EMAILER" = "yes" ]; then
    ask "NA_EMAIL_FROM" "Sender address" "noreply@example.com"
    ask "NA_EMAIL_TO" "Default recipient address" "team@example.com"
    ask "NA_SMTP_HOST" "SMTP host" "smtp.example.com"
    ask "NA_SMTP_PORT" "SMTP port" "587"
    ask "NA_SMTP_USER" "SMTP user" "user@example.com"
    ask "NA_SMTP_PASSWORD" "SMTP password" ""
    ask "NA_SMTP_STARTTLS" "Use STARTTLS? (true/false)" "true"
fi

ask "NA_ENABLE_KAFKA" "Deploy a Kafka cluster for persistent event streaming? (yes/no)" "no" is_yes_no
if [ "$NA_ENABLE_KAFKA" = "yes" ]; then
    ask "NA_KAFKA_REPLICAS" "Kafka node pool replicas (combined broker+controller, KRaft mode)" "3"
    ask "NA_KAFKA_VOLUME_SIZE" "Persistent volume size per broker" "100Gi"
    ask "NA_KAFKA_VERSION" "Kafka version (must be supported by your Strimzi operator version)" "4.2.0"
fi

gomplate -f "knative-template.yaml" -o "generated-knative.yaml" \
    --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

gomplate -f "apisix-route-template.yaml" -o "generated-apisix-route.yaml" \
    --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

gomplate -f "na-values-template.yaml" -o "generated-na-values.yaml" \
    --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

if [ "$NA_ENABLE_KAFKA" = "yes" ]; then
    gomplate -f "kafka-cluster-template.yaml" -o "generated-kafka-cluster.yaml" \
        --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

echo ""
echo "Configuration files generated."