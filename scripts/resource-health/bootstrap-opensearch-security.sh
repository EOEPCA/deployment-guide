#!/bin/bash

# The opensearch chart ships no automation for applying the mounted
# security config (roles, internal users, role mappings) to the cluster -
# without this, every OpenSearch-backed request fails with
# "OpenSearch Security not initialized." This runs the equivalent of the
# upstream securityadmin.sh manually, and is safe to re-run any time the
# security config changes (e.g. after a `helm upgrade`).

source ../common/utils.sh

NAMESPACE="resource-health"
POD="resource-health-opensearch-0"

echo "Waiting for ${POD} to be ready..."
kubectl wait --for=condition=ready "pod/${POD}" -n "$NAMESPACE" --timeout=300s

echo "Applying OpenSearch security config..."
kubectl exec -n "$NAMESPACE" "$POD" -- \
  /usr/share/opensearch/plugins/opensearch-security/tools/securityadmin.sh \
  -cd /usr/share/opensearch/config/opensearch-security \
  -icl -nhnv \
  -cacert /usr/share/opensearch/config/admin-certs/ca.crt \
  -cert /usr/share/opensearch/config/admin-certs/tls.crt \
  -key /usr/share/opensearch/config/admin-certs/tls.key

echo "✅ OpenSearch security config applied."
