#!/bin/bash

# utils.sh - Shared utility functions for EOEPCA deployment scripts

# Template paths
TEMPLATE_PATH="./values-template.yaml"
OUTPUT_PATH="./generated-values.yaml"
INGRESS_TEMPLATE_PATH="./ingress-template.yaml"
INGRESS_OUTPUT_PATH="./generated-ingress.yaml"
GATEKEEPER_TEMPLATE_PATH="./gatekeeper-template.yaml"
GATEKEEPER_OUTPUT_PATH="./generated-gatekeeper-values.yaml"

# Create and source the EOEPCA state file
create_state_file() {
    STATE_FILE="$HOME/.eoepca/state"
    ANNOTATIONS_FILE="$HOME/.eoepca/annotations.yaml"

    if [ ! -f "$STATE_FILE" ]; then
        mkdir -p "$(dirname "$STATE_FILE")"
        touch "$STATE_FILE"
    fi

    if [ ! -f "$ANNOTATIONS_FILE" ]; then
        touch "$ANNOTATIONS_FILE"
    fi

    source "$STATE_FILE"
}
create_state_file

# Check if a command exists
command_exists() {
    command -v "$@" >/dev/null 2>&1
}

# Confirm gomplate is installed
if ! command_exists gomplate; then
    echo "❌ The 'gomplate' command is required but not installed."
    echo "Run 'curl -L -o gomplate https://github.com/hairyhenderson/gomplate/releases/download/v4.3.0/gomplate_linux-amd64'"
    echo "chmod +x gomplate"
    echo "sudo mv gomplate /usr/local/bin/"
    exit 1
fi

# Prompt for user input with optional validation
ask() {
    local variable="$1"
    local message="$2"
    local default_value="$3"
    local validation_function="$4"

    # Check if the variable is already set
    if [ -n "${!variable+x}" ]; then
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

ask_temp() {
    local variable="$1"
    local message="$2"
    local default_value="$3"
    local validation_function="$4"

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
            break
        fi
    done

    # Export variable temporarily
    export "$variable=$input"
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

load_custom_ingress_annotations() {
    export GOMPLATE_DATASOURCE_ANNOTATIONS="$HOME/.eoepca/annotations.yaml"
}
load_custom_ingress_annotations


add_to_custom_ingress_annotations() {
    local annotation="$1"

    if grep -q "$annotation" "$HOME/.eoepca/annotations.yaml"; then
      return
    fi
    echo "$annotation" >>"$HOME/.eoepca/annotations.yaml"
    load_custom_ingress_annotations
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
    local key_length="$1" # Desired key length: 16 or 32 characters

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

is_yes_no() {
    [[ "$1" == "yes" || "$1" == "no" ]]
}

configure_http_scheme() {
    if [ -z "${HTTP_SCHEME-}" ]; then
        ask "HTTP_SCHEME" "Specify the HTTP scheme for the EOEPCA services (http/https)" "https" is_non_empty
    fi
}

configure_cert() {
    if [ -z "${USE_CERT_MANAGER-}" ]; then
        ask_yes_no "Do you use automatic certificate issuance with cert-manager (yes/no)?"
        if [ "$?" == 1 ]; then
            add_to_state_file "USE_CERT_MANAGER" "no"
        else
            add_to_state_file "USE_CERT_MANAGER" "yes"
        fi
    fi

    if [ "$USE_CERT_MANAGER" == "yes" ]; then
        ask "CLUSTER_ISSUER" "Specify the Cert Manager cluster issuer for TLS certificates" "letsencrypt-http01-apisix" is_non_empty
        add_to_state_file "CLUSTER_ISSUER_ANNOTATION" "cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}"
        add_to_custom_ingress_annotations "cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}"
    fi
}

configure_ingress() {
    if [ -z "${INGRESS_CLASS-}" ]; then
        ask "INGRESS_CLASS" "Specify the Ingress class for the EOEPCA services (apisix/nginx)" "apisix" is_non_empty
        if [ -f "$HOME/.eoepca/annotations.yaml" ]; then
            rm "$HOME/.eoepca/annotations.yaml"
            create_state_file
        fi
    fi

    if [ "$INGRESS_CLASS" == "nginx" ]; then
        add_to_custom_ingress_annotations "nginx.ingress.kubernetes.io/ssl-redirect: \"true\""
        add_to_custom_ingress_annotations "nginx.ingress.kubernetes.io/force-ssl-redirect: \"true\""
    fi

    if [ "$INGRESS_CLASS" == "apisix" ]; then
        add_to_custom_ingress_annotations "apisix.apache.org/ssl-redirect: \"true\""
        add_to_custom_ingress_annotations "apisix.ingress.kubernetes.io/use-regex: \"true\""
        add_to_custom_ingress_annotations "k8s.apisix.apache.org/upstream-read-timeout: \"600s\""
        add_to_custom_ingress_annotations "k8s.apisix.apache.org/http-to-https: \"true\""
    fi
}

first_time_setup() {
    if [ -z "${INGRESS_CLASS-}" ] || [ -z "${HTTP_SCHEME-}" ]; then
        echo "
        ███████╗░█████╗░███████╗██████╗░░█████╗░░█████╗░░░░░░░░
        ██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗██╔══██╗░░██╗░░
        █████╗░░██║░░██║█████╗░░██████╔╝██║░░╚═╝███████║██████╗
        ██╔══╝░░██║░░██║██╔══╝░░██╔═══╝░██║░░██╗██╔══██║╚═██╔═╝
        ███████╗╚█████╔╝███████╗██║░░░░░╚█████╔╝██║░░██║░░╚═╝░░
        ╚══════╝░╚════╝░╚══════╝╚═╝░░░░░░╚════╝░╚═╝░░╚═╝░░░░░░░"

        echo ""
        echo "Earth Observation Exploitation Platform Common Architecture Deployment Guide scripts"
        echo ""
        echo "These scripts accompany the EOEPCA Deployment Guide and are used to configure the deployment of the EOEPCA Building Blocks."
        echo "https://eoepca.readthedocs.io/projects/deploy/en/latest/"
        echo ""
        echo "State variables are stored in $HOME/.eoepca/state."
        echo "As you are running this script for the first time, you will be prompted to configure some settings. These settings will be saved for future runs and ensure integration between the Building Blocks."
        echo "You can use enter to accept the default values or previously configured values."
        echo ""
        echo "Please configure the following settings:"
        echo ""
        configure_ingress
        configure_http_scheme
        ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
        ask "STORAGE_CLASS" "Specify the Kubernetes storage class for persistent volumes" "standard" is_non_empty
        configure_cert
        echo ""
        echo "✅ First time setup complete. These values are stored in the state file which are used to configure the Building Blocks."
        echo "To reset your configuration, delete the state file at $HOME/.eoepca/state."
        echo ""
        echo "Moving on..."
        echo ""
    fi
}
first_time_setup
