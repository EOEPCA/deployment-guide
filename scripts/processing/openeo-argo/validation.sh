#!/bin/bash
source ../../common/utils.sh
source ../../common/validation-utils.sh

echo "🔍 Validating OpenEO ArgoWorkflows deployment..."

check_pods_running "openeo" "app.kubernetes.io/name=openeo-argo" 1
check_pods_running "openeo" "app.kubernetes.io/name=postgresql" 1
check_pods_running "openeo" "app.kubernetes.io/name=redis" 1

check_service_exists "openeo" "openeo-openeo-argo"
check_service_exists "openeo" "openeo-postgresql"
check_service_exists "openeo" "openeo-redis-master"

# Check the shared (ReadWriteMany) job workspace PVC bound successfully
check_pvc_bound "openeo" "openeo-workspace"

# Check API endpoints. If OIDC is disabled, requests go through the basic-auth
# proxy instead of the API directly, so they need credentials.
if [ "$OPENEO_ARGO_ENABLE_OIDC" == "no" ]; then
  CHECK_USER="$OPENEO_ARGO_BASIC_AUTH_USERNAME" CHECK_PASSWORD="$OPENEO_ARGO_BASIC_AUTH_PASSWORD" \
    check_url_status_code "$HTTP_SCHEME://openeo.$INGRESS_HOST/" 200
  CHECK_USER="$OPENEO_ARGO_BASIC_AUTH_USERNAME" CHECK_PASSWORD="$OPENEO_ARGO_BASIC_AUTH_PASSWORD" \
    check_url_status_code "$HTTP_SCHEME://openeo.$INGRESS_HOST/processes" 200
else
  check_url_status_code "$HTTP_SCHEME://openeo.$INGRESS_HOST/openeo/1.1.0" 200
  check_url_status_code "$HTTP_SCHEME://openeo.$INGRESS_HOST/openeo/1.1.0/processes" 200
  check_keycloak_client_ready "iam-management" "openeo-argo" \
    "Apply the Client CR from Step 7 of the guide."
fi

# Test database connectivity (postgresql/redis are StatefulSets, not Deployments)
echo "Testing PostgreSQL connectivity..."
kubectl exec -n openeo openeo-postgresql-0 -- \
  bash -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -d openeo -c "SELECT 1"' &>/dev/null && \
  echo "✅ PostgreSQL is accessible" || echo "❌ PostgreSQL connection failed"

# Test Redis connectivity
echo "Testing Redis connectivity..."
kubectl exec -n openeo openeo-redis-master-0 -- \
  redis-cli ping &>/dev/null && \
  echo "✅ Redis is accessible" || echo "❌ Redis connection failed"

# Check service account token
echo "Checking service account token..."
kubectl get secret -n openeo openeo-argo-access-sa.service-account-token &>/dev/null && \
  echo "✅ Service account token exists" || echo "❌ Service account token missing"

echo
echo "All Resources in openeo namespace:"
kubectl get all -n openeo

echo
echo "✅ OpenEO ArgoWorkflows validation completed."