#!/bin/bash

# Common functions for validation

# Function to check if pods with a given label are running and ready
function check_pods_running() {
    local namespace="$1"
    local label_selector="$2"
    local expected_count="$3"
    local running_count

    running_count=$(kubectl get pods -n "$namespace" -l "$label_selector" --field-selector=status.phase=Running 2>/dev/null | grep -c 'Running')

    if [ "$running_count" -ge "$expected_count" ]; then
        echo "✅ $running_count pod(s) with label '$label_selector' are running."
        return 0
    else
        echo "❌ Expected $expected_count pod(s) with label '$label_selector' to be running, but found $running_count."
        return 1
    fi
}

# Function to check if deployments are ready
function check_deployment_ready() {
    local namespace="$1"
    local deployment_name="$2"

    if kubectl rollout status deployment "$deployment_name" -n "$namespace" --timeout=60s >/dev/null 2>&1; then
        echo "✅ Deployment '$deployment_name' is ready."
        return 0
    else
        echo "❌ Deployment '$deployment_name' is not ready."
        return 1
    fi
}

# Function to check if a service is available
function check_service_exists() {
    local namespace="$1"
    local service_name="$2"

    if kubectl get service "$service_name" -n "$namespace" >/dev/null 2>&1; then
        echo "✅ Service '$service_name' exists."
        return 0
    else
        echo "❌ Service '$service_name' does not exist."
        return 1
    fi
}

# Function to perform a curl request and check for a specific HTTP status code
function check_url_status_code() {
    local url="$1"
    local expected_code="$2"
    local basic_auth=""
    local curl_redirect=""

    if [ -n "${CHECK_USER:-}" ] && [ -n "${CHECK_PASSWORD:-}" ]; then
        basic_auth="-u ${CHECK_USER}:${CHECK_PASSWORD}"
    fi

    if [ -z "${CHECK_URL_NO_REDIRECT:-}" ]; then
        curl_redirect="-L"
    fi

    local actual_code
    actual_code=$(curl ${basic_auth} ${curl_redirect} -k -s -o /dev/null -w "%{http_code}" "$url")

    if [ "$actual_code" -eq "$expected_code" ]; then
        echo "✅ URL '$url' returned expected HTTP status code $expected_code."
        return 0
    else
        echo "❌ URL '$url' returned HTTP status code $actual_code, expected $expected_code."
        return 1
    fi
}

# Function to check if PVCs are bound
function check_pvc_bound() {
    local namespace="$1"
    local pvc_name="$2"
    local status
    status=$(kubectl get pvc "$pvc_name" -n "$namespace" -o jsonpath='{.status.phase}')

    if [ "$status" = "Bound" ]; then
        echo "✅ PVC '$pvc_name' is bound."
        return 0
    else
        echo "❌ PVC '$pvc_name' is not bound. Current status: $status."
        return 1
    fi
}

# Function to check the status of a StatefulSet
function check_statefulset_ready() {
    local namespace="$1"
    local statefulset_name="$2"

    if kubectl rollout status statefulset "$statefulset_name" -n "$namespace" --timeout=60s >/dev/null 2>&1; then
        echo "✅ StatefulSet '$statefulset_name' is ready."
        return 0
    else
        echo "❌ StatefulSet '$statefulset_name' is not ready."
        return 1
    fi
}

# Function to check the status of a DaemonSet
function check_daemonset_ready() {
    local namespace="$1"
    local daemonset_name="$2"

    if kubectl rollout status daemonset "$daemonset_name" -n "$namespace" --timeout=60s >/dev/null 2>&1; then
        echo "✅ DaemonSet '$daemonset_name' is ready."
        return 0
    else
        echo "❌ DaemonSet '$daemonset_name' is not ready."
        return 1
    fi
}

# Function to check if a ConfigMap exists
function check_configmap_exists() {
    local namespace="$1"
    local configmap_name="$2"

    if kubectl get configmap "$configmap_name" -n "$namespace" >/dev/null 2>&1; then
        echo "✅ ConfigMap '$configmap_name' exists."
        return 0
    else
        echo "❌ ConfigMap '$configmap_name' does not exist."
        return 1
    fi
}

# Function to check if a ServiceAccount exists
function check_serviceaccount_exists() {
    local namespace="$1"
    local serviceaccount_name="$2"

    if kubectl get serviceaccount "$serviceaccount_name" -n "$namespace" >/dev/null 2>&1; then
        echo "✅ ServiceAccount '$serviceaccount_name' exists."
        return 0
    else
        echo "❌ ServiceAccount '$serviceaccount_name' does not exist."
        return 1
    fi
}

# Function to check if a CronJob exists
function check_cronjob_exists() {
    local namespace="$1"
    local cronjob_name="$2"

    if kubectl get cronjob "$cronjob_name" -n "$namespace" >/dev/null 2>&1; then
        echo "✅ CronJob '$cronjob_name' exists."
        return 0
    else
        echo "❌ CronJob '$cronjob_name' does not exist."
        return 1
    fi
}

# Function to check if a Secret exists
function check_secret_exists() {
    local namespace="$1"
    local secret_name="$2"

    if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
        echo "✅ Secret '$secret_name' exists."
        return 0
    else
        echo "❌ Secret '$secret_name' does not exist."
        return 1
    fi
}

function check_keycloak_provider_config_exists() {
    local namespace="${1:-iam-management}"
    local provider_config_name="${2:-keycloak-provider-config}"

    if kubectl get providerconfig.keycloak.m.crossplane.io "$provider_config_name" -n "$namespace" >/dev/null 2>&1; then
        echo "✅ Keycloak ProviderConfig '$provider_config_name' exists in namespace '$namespace'."
        return 0
    fi

    echo "❌ Keycloak ProviderConfig '$provider_config_name' does not exist in namespace '$namespace'."
    return 1
}

function check_keycloak_client_secret_exists() {
    local namespace="$1"
    local client_id="$2"
    local secret_name="${3:-${client_id}-keycloak-client}"

    check_secret_exists "$namespace" "$secret_name"
}

function check_keycloak_client_ready() {
    local namespace="$1"
    local client_id="$2"
    local apply_hint="${3:-Apply the generated IAM manifest and check Crossplane reconciliation.}"
    local client_resource="client.openidclient.keycloak.m.crossplane.io/${client_id}"

    if ! kubectl get "$client_resource" -n "$namespace" >/dev/null 2>&1; then
        echo "❌ Keycloak Client '$client_id' does not exist in namespace '$namespace'."
        echo "   $apply_hint"
        return 1
    fi

    if kubectl wait --for=condition=Ready "$client_resource" -n "$namespace" --timeout=60s >/dev/null 2>&1; then
        echo "✅ Keycloak Client '$client_id' is ready."
        return 0
    fi

    echo "❌ Keycloak Client '$client_id' is not ready."
    kubectl get "$client_resource" -n "$namespace" -o jsonpath='{range .status.conditions[*]}{.type}={.status}: {.reason} {.message}{"\n"}{end}' 2>/dev/null || true
    return 1
}

function check_keycloak_user_ready() {
    local namespace="$1"
    local resource_name="$2"
    local apply_hint="${3:-Apply the generated Crossplane User manifest and check Crossplane reconciliation.}"
    local user_resource="user.user.keycloak.m.crossplane.io/${resource_name}"

    if ! kubectl get "$user_resource" -n "$namespace" >/dev/null 2>&1; then
        echo "❌ Keycloak User '$resource_name' does not exist in namespace '$namespace'."
        echo "   $apply_hint"
        return 1
    fi

    if kubectl wait --for=condition=Ready "$user_resource" -n "$namespace" --timeout=60s >/dev/null 2>&1; then
        echo "✅ Keycloak User '$resource_name' is ready."
        return 0
    fi

    echo "❌ Keycloak User '$resource_name' is not ready."
    kubectl get "$user_resource" -n "$namespace" -o jsonpath='{range .status.conditions[*]}{.type}={.status}: {.reason} {.message}{"\n"}{end}' 2>/dev/null || true
    return 1
}

check_crd_exists() {
  if kubectl get crd "$1" >/dev/null 2>&1; then
    echo "✅ CRD '$1' exists."
  else
    echo "❌ CRD '$1' missing."
  fi
}

# Function to check if a (cluster-scoped) Kyverno ClusterPolicy exists
function check_clusterpolicy_exists() {
    local policy_name="$1"

    if kubectl get clusterpolicy "$policy_name" >/dev/null 2>&1; then
        echo "✅ Kyverno ClusterPolicy '$policy_name' exists."
        return 0
    else
        echo "❌ Kyverno ClusterPolicy '$policy_name' does not exist."
        return 1
    fi
}

function check_s3_bucket_exists() {
    local bucket_name="$1"

    if ! command -v s3cmd &>/dev/null; then
        echo "⚠️  s3cmd not installed - skipping existence check for S3 bucket '$bucket_name'."
        return 0
    fi

    local s3_host="${S3_ENDPOINT#*://}"
    if s3cmd ls "s3://${bucket_name}" \
        --host="$s3_host" --host-bucket="$s3_host" \
        --access_key="$S3_ACCESS_KEY" --secret_key="$S3_SECRET_KEY" >/dev/null 2>&1; then
        echo "✅ S3 bucket '$bucket_name' exists."
        return 0
    else
        echo "❌ S3 bucket '$bucket_name' does not exist or is not reachable at $S3_ENDPOINT."
        echo "   Create it first - e.g. via the MinIO console, or: s3cmd mb s3://${bucket_name} --host=$s3_host --host-bucket=$s3_host --access_key=\$S3_ACCESS_KEY --secret_key=\$S3_SECRET_KEY"
        return 1
    fi
}
