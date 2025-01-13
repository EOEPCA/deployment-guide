#!/bin/bash

# utils.sh - Shared utility functions for EOEPCA deployment scripts

# Template paths
TEMPLATE_PATH="./values-template.yaml"
OUTPUT_PATH="./generated-values.yaml"
GATEKEEPER_TEMPLATE_PATH="./gatekeeper-template.yaml"
GATEKEEPER_OUTPUT_PATH="./generated-gatekeeper-values.yaml"

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

    add_to_state_file "$variable" "$input"
}

add_to_state_file() {
    local variable="$1"
    local value="$2"

    export "$variable=$value"

    if grep -q "export $variable=" "$HOME/.eoepca/state"; then
        sed -i "s|export $variable=.*|export $variable=\"$value\"|" "$HOME/.eoepca/state"
    else
        echo "export $variable=\"$value\"" >>"$HOME/.eoepca/state"
    fi
}

check() {
    local message="$1"
    local error_message="$2"

    read -p "$message (yes/no): " RESPONSE
    if [[ "$RESPONSE" != "yes" ]]; then
        echo "$error_message"
        exit 1
    fi
}

ask_yes_no() {
    local message="$1"
    read -p "$message (yes/no): " RESPONSE
    if [[ "$RESPONSE" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to generate a secure password and encode it in base64
generate_password() {
    head -c 32 /dev/urandom | base64
}

generate_aes_key() {
    local key_length="$1"  # Desired key length: 16 or 32 characters

    if [[ "$key_length" != "16" && "$key_length" != "32" ]]; then
        echo "Invalid key length: $key_length. Please specify 16 or 32." >&2
        return 1
    fi

    # Generate a URL-safe base64 string
    openssl rand -base64 $key_length | tr -dc 'A-Za-z0-9' | head -c "$key_length"
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

configure_cert() {
    if [ -z "$USE_CERT_MANAGER" ]; then
        ask_yes_no "Do you want to use automatic certificate issuance with cert-manager (yes/no)?"
        if [ "$?" == 1 ]; then
            add_to_state_file "USE_CERT_MANAGER" "no"
        else
            add_to_state_file "USE_CERT_MANAGER" "yes"
        fi
    fi

    if [ "$USE_CERT_MANAGER" == "yes" ]; then
        ask "CLUSTER_ISSUER" "Specify the Cert Manager cluster issuer for TLS certificates" "letsencrypt-http01-apisix" is_non_empty
        add_to_state_file "CLUSTER_ISSUER_ANNOTATION" "cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}"
    else
        add_to_state_file "CLUSTER_ISSUER_ANNOTATION" ""
    fi
}

configure_http_scheme() {
    if [ -z "$HTTP_SCHEME" ]; then
        ask "HTTP_SCHEME" "Specify the HTTP scheme for the EOEPCA services (http/https)" "https" is_non_empty
    fi
}
configure_http_scheme