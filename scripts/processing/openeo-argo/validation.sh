#!/bin/bash
source ../../common/utils.sh
source ../../common/validation-utils.sh

echo "🔍 Validating OpenEO ArgoWorkflows deployment..."

# Check pods
check_pods_running "openeo" "app.kubernetes.io/name=openeo-argo" 1
check_pods_running "openeo" "app.kubernetes.io/name=postgresql" 1
check_pods_running "openeo" "app.kubernetes.io/name=redis" 1

# Check services
check_service_exists "openeo" "openeo-openeo-argo"
check_service_exists "openeo" "openeo-postgresql"
check_service_exists "openeo" "openeo-redis-master"

# Check API endpoints
check_url_status_code "$HTTP_SCHEME://openeo.$INGRESS_HOST/" 200
check_url_status_code "$HTTP_SCHEME://openeo.$INGRESS_HOST/processes" 200

# Test database connectivity
echo "Testing PostgreSQL connectivity..."
kubectl exec -n openeo deploy/openeo-postgresql -- \
  psql -U postgres -d openeo -c "SELECT 1" &>/dev/null && \
  echo "✅ PostgreSQL is accessible" || echo "❌ PostgreSQL connection failed"

# Test Redis connectivity
echo "Testing Redis connectivity..."
kubectl exec -n openeo deploy/openeo-redis-master -- \
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