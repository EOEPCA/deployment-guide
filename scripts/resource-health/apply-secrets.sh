#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh

NAMESPACE="resource-health"

echo "Applying Kubernetes secrets for Resource Health..."

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

if [ "$RESOURCE_HEALTH_ENABLE_OIDC" = "yes" ]; then
  # IAM client credentials + APISIX openid-connect session secret, referenced
  # via secretRef from the ApisixPluginConfig plugins.
  kubectl create secret generic resource-health-iam-client-credentials \
    --from-literal=client_id="$RESOURCE_HEALTH_CLIENT_ID" \
    --from-literal=client_secret="$RESOURCE_HEALTH_CLIENT_SECRET" \
    --from-literal=session.secret="$RESOURCE_HEALTH_SESSION_SECRET" \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

# The alerting component is always deployed by the chart, so these are always
# needed (with safe placeholder values if RESOURCE_HEALTH_ENABLE_ALERTING=no).
kubectl create secret generic resource-health-notifier-email-credentials \
  --from-literal=from_email="$RESOURCE_HEALTH_FROM_EMAIL" \
  --from-literal=from_email_password="$RESOURCE_HEALTH_FROM_EMAIL_PASSWORD" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic resource-health-alerting-user-emails \
  --from-literal=alert_user_emails.json='{}' \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Resource Health secrets applied."