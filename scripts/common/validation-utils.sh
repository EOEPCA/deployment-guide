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

    if [ -n "${CHECK_USER}" -a -n "${CHECK_PASSWORD}" ]; then
        BASIC_AUTH="-u ${CHECK_USER}:${CHECK_PASSWORD}"
    fi

    local actual_code
    actual_code=$(curl ${BASIC_AUTH} -k -s -o /dev/null -w "%{http_code}" "$url")

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

