#!/bin/bash

# Function to check if a command exists
function check_command_installed() {
    local cmd="$1"
    local install_url="$2"
    local cmd_pretty_name="$3"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ $cmd_pretty_name is not installed."
        echo "   Please install $cmd_pretty_name."
        if [ -n "$install_url" ]; then
            echo "   Installation instructions: $install_url"
        fi
        return 1
    else
        echo "✅ $cmd_pretty_name is installed."
        return 0
    fi
}

# Function to check if a command meets the required version
function check_command_version() {
    local cmd="$1"
    local required_version="$2"
    local version_command="$3"
    local version_regex="$4"
    local install_url="$5"
    local cmd_pretty_name="$6"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ $cmd_pretty_name is not installed."
        echo "   Please install $cmd_pretty_name."
        if [ -n "$install_url" ]; then
            echo "   Installation instructions: $install_url"
        fi
        return 1
    fi

    # Get the installed version
    local installed_version
    installed_version=$(eval "$version_command" 2>/dev/null | grep -Eo "$version_regex" | head -n1)

    if [ -z "$installed_version" ]; then
        echo "⚠️  Could not determine version of $cmd_pretty_name."
        return 1
    fi

    # Compare versions
    if [ "$(printf '%s\n' "$required_version" "$installed_version" | sort -V | head -n1)" = "$required_version" ]; then
        echo "✅ $cmd_pretty_name version $installed_version meets the requirement (>= $required_version)."
        return 0
    else
        echo "❌ $cmd_pretty_name version $installed_version is less than required version $required_version."
        if [ -n "$install_url" ]; then
            echo "   Please update $cmd_pretty_name. Installation instructions: $install_url"
        fi
        return 1
    fi
}

# Function to check Kubernetes cluster accessibility
function check_kubernetes_access() {
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "❌ Kubernetes cluster is not accessible with kubectl."
        echo "   Please ensure your kubeconfig is correctly configured."
        return 1
    else
        echo "✅ Kubernetes cluster is accessible."
        return 0
    fi
}

# Specific checks for common tools
function check_kubectl_installed() {
    check_command_installed "kubectl" "https://kubernetes.io/docs/tasks/tools/install-kubectl/" "kubectl"
}

function check_helm_installed() {
    check_command_version "helm" "3.5" "helm version --short | sed 's/^v//'" "[0-9]+\.[0-9]+\.[0-9]+" "https://helm.sh/docs/intro/install/" "Helm"
}

function check_git_installed() {
    check_command_installed "git" "https://git-scm.com/book/en/v2/Getting-Started-Installing-Git" "Git"
}

function check_python3_installed() {
    check_command_installed "python3" "https://www.python.org/downloads/" "Python 3"
}

function check_docker_installed() {
    check_command_version "docker" "19.03" "docker --version | awk '{print \$3}' | sed 's/,//'" "[0-9]+\.[0-9]+\.[0-9]+" "https://docs.docker.com/get-docker/" "Docker"
}

function check_cert_manager_installed() {
    if ! kubectl get pods --all-namespaces | grep -q cert-manager; then
        echo "❌ Cert-Manager is not installed in the cluster."
        echo "   Please install Cert-Manager: https://cert-manager.io/docs/installation/"
        return 1
    else
        echo "✅ Cert-Manager is installed."
        return 0
    fi
}

# Improve this
function check_ingress_controller_installed() {
    if ! kubectl get pods --all-namespaces | grep -q 'ingress";'; then
        echo "❌ Ingress Controller is not installed in the cluster."
        echo "   Please install NGINX Ingress Controller: https://kubernetes.github.io/ingress-nginx/deploy/"
        return 1
    else
        echo "✅ Ingress Controller is installed."
        return 0
    fi
}

function check_keycloak_accessible() {
    local KEYCLOAK_URL="$1"
    if curl -s -o /dev/null -w "%{http_code}" https://"$KEYCLOAK_URL" | grep -qE "200"; then
        echo "✅ Keycloak (Identity Service) is accessible at $KEYCLOAK_URL"
        return 0
    else
        echo "❌ Keycloak (Identity Service) is not accessible at https://$KEYCLOAK_URL"
        echo "   Please ensure the Identity Service is deployed and accessible."
        echo "   Deployment guide: https://eoepca.github.io/deployment-guide/identity-service-deployment"
        return 1
    fi
}

function run_validation() {

    checks=("$@")
    errors=0

    # Loop through each check function in the array
    for check in "${checks[@]}"; do
        if ! $check; then
            # Special message for optional cases... Improve this....
            if [[ "$check" == "check_python3_installed" ]]; then
                echo "⚠️  Python 3 is not installed. Some helper scripts may not work."
            else
                errors=$((errors + 1))
            fi
        fi
    done

    if [ "$errors" -eq 0 ]; then
        echo "✅ All prerequisites are met. You can proceed with the deployment."
    else
        echo "❌ There are $errors errors in the prerequisites. Please fix them before proceeding."
    fi
}
