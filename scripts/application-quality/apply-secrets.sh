# Load utility functions and state file
source ../common/utils.sh
source ~/.eoepca/state

NAMESPACE="application-quality"

echo "Applying secrets to namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic application-quality-auth-client \
    --from-literal=OIDC_RP_CLIENT_ID="$APP_QUALITY_CLIENT_ID" \
    --from-literal=OIDC_RP_CLIENT_SECRET="$APP_QUALITY_CLIENT_SECRET" \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -



kubectl create secret generic application-quality-opensearch-dashboards-openid-config \
    --from-literal=OPENSEARCH_SECURITY_OPENID_BASE_REDIRECT_URL="${HTTP_SCHEME}://${APP_QUALITY_PUBLIC_HOST}/dashboards" \
    --from-literal=OPENSEARCH_SECURITY_OPENID_CLIENT_ID="$APP_QUALITY_CLIENT_ID" \
    --from-literal=OPENSEARCH_SECURITY_OPENID_CLIENT_SECRET="$APP_QUALITY_CLIENT_SECRET" \
    --from-literal=OPENSEARCH_SECURITY_OPENID_CONNECT_URL="${HTTP_SCHEME}://${KEYCLOAK_HOST}/auth/realms/${REALM}/.well-known/openid-configuration" \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic application-quality-grafana-dashboards-admin-creds \
    --from-literal=GRAFANA_SECURITY_ADMIN_USER="admin" \
    --from-literal=GRAFANA_SECURITY_ADMIN_PASSWORD="admin" \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -


echo "✅ Secrets applied in namespace: $NAMESPACE"
