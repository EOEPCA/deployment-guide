#!/bin/bash

# utils.sh - Shared utility functions for EOEPCA deployment scripts

# Template paths
TEMPLATE_PATH="./values-template.yaml"
OUTPUT_PATH="./generated-values.yaml"

# Ensure the template file exists
if [ ! -f "$TEMPLATE_PATH" ]; then
    echo "❌ Template file '$TEMPLATE_PATH' not found."
    exit 1
fi

# Create and source the EOEPCA state file
create_state_file() {
    STATE_FILE="$HOME/.eoepca/state"

    if [ ! -f "$STATE_FILE" ]; then
        mkdir -p "$(dirname "$STATE_FILE")"
        touch "$STATE_FILE"
    fi

    source "$STATE_FILE"
}

create_state_file

# Check if a command exists
command_exists() {
    command -v "$@" >/dev/null 2>&1
}

# Prompt for user input with optional validation
ask() {
    local variable="$1"
    local message="$2"
    local default_value="$3"
    local validation_function="$4"

    # Check if the variable is already set
    if [ -n "${!variable}" ]; then
        echo "$variable is already set to '${!variable}'. Do you want to update it? (y/n)"
        read -r update
        if [[ "$update" != "y" ]]; then
            return
        fi
    fi

    while true; do
        # Prompt for input
        if [ -n "$default_value" ]; then
            read -rp "$message [Default: $default_value]: " input
        else
            read -rp "$message: " input
        fi
        input="${input:-$default_value}"

        # Validate input
        if [ -n "$validation_function" ]; then
            if "$validation_function" "$input"; then
                break
            else
                echo "Invalid input. Please try again."
            fi
        elif [ -n "$input" ]; then
            break
        else
            echo "Input cannot be empty. Please try again."
        fi
    done

    # Export variable and update state file
    export "$variable=$input"

    if grep -q "export $variable=" "$HOME/.eoepca/state"; then
        sed -i "s|export $variable=.*|export $variable=\"$input\"|" "$HOME/.eoepca/state"
    else
        echo "export $variable=\"$input\"" >>"$HOME/.eoepca/state"
    fi
}


# Function to generate a secure password and encode it in base64
generate_password() {
    head -c 32 /dev/urandom | base64
}

# Check if a Kubernetes resource exists
check_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="$3"

    if kubectl get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1; then
        echo "✅ $resource_type $resource_name found in namespace $namespace."
    else
        echo "❌ $resource_type $resource_name not found in namespace $namespace."
        exit 1
    fi
}

# Check if pods with a specific label are running
check_pods() {
    local namespace="$1"
    local label_selector="$2"
    echo "Checking if all pods with label '$label_selector' are in 'Running' state..."

    local pods
    pods=$(kubectl get pods -n "$namespace" -l "$label_selector" --no-headers)
    if [ -z "$pods" ]; then
        echo "❌ No pods found with label '$label_selector' in namespace '$namespace'."
        exit 1
    fi

    local all_running=true
    while read -r pod_line; do
        local pod_name pod_status
        pod_name=$(echo "$pod_line" | awk '{print $1}')
        pod_status=$(echo "$pod_line" | awk '{print $3}')

        if [ "$pod_status" != "Running" ]; then
            echo "❌ Pod $pod_name is not running (status: $pod_status)."
            all_running=false
        else
            echo "✅ Pod $pod_name is running."
        fi
    done <<<"$pods"

    if [ "$all_running" = false ]; then
        echo "Some pods are not running. Please check the pod statuses."
        exit 1
    fi
}

# Validation functions
is_boolean() {
    [[ "$1" == "true" || "$1" == "false" ]]
}

is_non_empty() {
    [[ -n "$1" ]]
}

is_valid_domain() {
    [[ "$1" =~ ^[a-zA-Z0-9.-]+$ ]]
}

# Check if envsubst is available
if ! command_exists envsubst; then
    echo "❌ The 'envsubst' command is required but not installed."
    echo "Run 'apt install gettext' to use 'envsubst'."
    exit 1
fi