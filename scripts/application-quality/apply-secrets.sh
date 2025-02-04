# Load utility functions and state file
source ../common/utils.sh

NAMESPACE="application-quality"

echo "Applying secrets to namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic application-quality-auth-client \
    --from-literal=OIDC_RP_CLIENT_ID="$OIDC_RP_CLIENT_ID" \
    --from-literal=OIDC_RP_CLIENT_SECRET="$OIDC_RP_CLIENT_SECRET" \
    --namespace "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# kubectl create secret generic application-quality-opensearch-dashboards-openid-config \
#     --from-literal=OPENSEARCH_SECURITY_OPENID_BASE_REDIRECT_URL="$OSD_BASE_REDIRECT" \
#     --from-literal=OPENSEARCH_SECURITY_OPENID_CLIENT_ID="$OSD_CLIENT_ID" \
#     --from-literal=OPENSEARCH_SECURITY_OPENID_CLIENT_SECRET="$OSD_CLIENT_SECRET" \
#     --from-literal=OPENSEARCH_SECURITY_OPENID_CONNECT_URL="$OSD_CONNECT_URL" \
#     --namespace "$NAMESPACE" \
#     --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets applied in namespace: $NAMESPACE"
