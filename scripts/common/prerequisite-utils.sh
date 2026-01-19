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

function check_helm_plugin_installed() {
    local plugin_name="$1"
    local install_url="$2"
    if helm plugin list | grep "^${plugin_name}\s" >/dev/null; then
        echo "✅ Helm plugin ${plugin_name} is installed."
        return 0
    else
        echo "❌ Helm plugin ${plugin_name} is NOT installed."
        if [ -n "$install_url" ]; then
            echo "   Please install the ${plugin_name} plugin. Installation instructions: $install_url"
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
    check_command_installed "kubectl" "$HTTP_SCHEME://kubernetes.io/docs/tasks/tools/install-kubectl/" "kubectl"
}

function check_helm_installed() {
    check_command_version "helm" "3.5" "helm version --short | sed 's/^v//'" "[0-9]+\.[0-9]+\.[0-9]+" "https://helm.sh/docs/intro/install/" "Helm"
}

function check_git_installed() {
    check_command_installed "git" "https://git-scm.com/book/en/v2/Getting-Started-Installing-Git" "Git"
}

function check_helm_git_plugin_installed() {
    check_helm_plugin_installed "helm-git" "https://github.com/aslafy-z/helm-git?tab=readme-ov-file#install"
}

function check_python3_installed() {
    check_command_installed "python3" "https://www.python.org/downloads/" "Python 3"
}

function check_docker_installed() {
    check_command_version "docker" "19.03" "docker --version | awk '{print \$3}' | sed 's/,//'" "[0-9]+\.[0-9]+\.[0-9]+" "https://docs.docker.com/get-docker/" "Docker"
}

function check_cert_manager_installed() {
    if [ "${USE_CERT_MANAGER}" = "yes" ]; then
        if ! kubectl get pods --all-namespaces | grep -q cert-manager; then
            echo "⚠️  Cert-Manager is not installed in the cluster."
            echo "   Please install Cert-Manager: https://cert-manager.io/docs/installation/"
            echo "   If you are manually managing certificates, you can ignore this message."
            return 1
        else
            echo "✅ Cert-Manager is installed."
            return 0
        fi
    fi
}

function check_ingress_controller_installed() {
    if kubectl get pods --all-namespaces | grep -Eq "apisix-ingress-controller|ingress-nginx-controller"; then
        echo "✅ An Ingress Controller is installed (either APISIX or Ingress-NGINX)."
        return 0
    else
        echo "⚠️  Neither APISIX Ingress Controller nor Ingress-NGINX Controller is installed in the cluster."
        echo "   Please install an Ingress Controller:"
        echo "     APISIX Ingress Controller: https://eoepca.readthedocs.io/projects/deploy/en/latest/prerequisites/ingress/apisix/"
        echo "     Ingress-NGINX Controller: https://eoepca.readthedocs.io/projects/deploy/en/latest/prerequisites/ingress/nginx/"
        return 1
    fi
}

function check_apisix_ingress_installed() {
    if kubectl get pods --all-namespaces | grep -q apisix-ingress-controller; then
        echo "✅ APISIX Ingress Controller is installed."
        return 0
    else
        echo "⚠️  APISIX Ingress Controller is not installed in the cluster."
        echo "   Please install APISIX Ingress Controller: https://eoepca.readthedocs.io/projects/deploy/en/latest/prerequisites/ingress/apisix/"
        return 1
    fi
}

function check_crossplane_installed() {
    if kubectl get deployments -A --no-headers | awk '{print $2}' | grep -q '^crossplane$'; then
        echo "✅ Crossplane is installed."
        return 0
    else
        echo "⚠️  Crossplane is not installed in the cluster."
        echo "   Please install Crossplane: https://eoepca.readthedocs.io/projects/deploy/en/latest/prerequisites/crossplane/"
        return 1
    fi
}

function check_keycloak_accessible() {
    local KEYCLOAK_URL="$1"
    if curl -s -o /dev/null -w "%{http_code}" $HTTP_SCHEME://"$KEYCLOAK_URL" | grep -qE "200"; then
        echo "✅ Keycloak (Identity Service) is accessible at $KEYCLOAK_URL"
        return 0
    else
        echo "❌ Keycloak (Identity Service) is not accessible at $HTTP_SCHEME://$KEYCLOAK_URL"
        echo "   Please ensure the Identity Service is deployed and accessible."
        echo "   Deployment guide: $HTTP_SCHEME://eoepca.github.io/deployment-guide/identity-service-deployment"
        return 1
    fi
}

function check_object_store_accessible() {
    if [ -z "$S3_HOST" ] && [ -z "$S3_ENDPOINT" ]; then
        echo "⚠️ S3_HOST or S3_ENDPOINT environment variable is not set."
        echo "   Please ensure that you have an accessible object store (S3-compatible)"
        echo "   You will be prompted to set these variables during the configuration script setup"
        return 1
    fi

    echo "✅ You have set the S3_HOST or S3_ENDPOINT environment variable."
}

function check_oidc_provider_accessible() {
    if [ -z "$OIDC_ISSUER_URL" ]; then

        if [ -z "$KEYCLOAK_HOST" ]; then
            ask "KEYCLOAK_HOST" "Enter the Keycloak full host domain excluding https (e.g., auth.example.com)" "auth.example.com" is_valid_domain
        fi

        if [ -z "$REALM" ]; then
            ask "REALM" "Enter the Keycloak realm" "eoepca" is_non_empty
        fi

        if [ -n "$KEYCLOAK_HOST" ] && [ -n "$REALM" ]; then
            OIDC_ISSUER_URL="$HTTP_SCHEME://${KEYCLOAK_HOST}/realms/${REALM}"
            add_to_state_file "OIDC_ISSUER_URL" "$OIDC_ISSUER_URL"
            validate_url "$OIDC_ISSUER_URL"

            echo "✅ OIDC_ISSUER_URL is set to $OIDC_ISSUER_URL"
            return 0
        fi

        echo "⚠️ OIDC_ISSUER_URL environment variable is not set."
        ask "OIDC_ISSUER_URL" "Enter the OIDC issuer URL" "https://keycloak.com/realms/eoepca" is_non_empty

        if [ -z "$OIDC_ISSUER_URL" ]; then
            echo "❌ OIDC_ISSUER_URL is not set."
            echo "   Please set the OIDC_ISSUER_URL environment variable."
            return 1
        fi

    fi

    validate_url "$OIDC_ISSUER_URL"
    echo "✅ You have set the OIDC_ISSUER_URL environment variable."
}

function validate_url() {
    local url="$1"
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -qE "200"; then
        echo "✅ URL $url is accessible."
        return 0
    else
        echo "❌ URL $url is not accessible."
        return 1
    fi
}

function check_internal_certificates() {
    # check if internal TLS has been enabled
    if [ -z "$INTERNAL_TLS_ENABLED" ] || [ "$INTERNAL_TLS_ENABLED" != "true" ]; then
        ask "INTERNAL_TLS_ENABLED" "Do you have internal TLS enabled with a valid Cluster Issuer?" "true" is_boolean

        if [ "$INTERNAL_TLS_ENABLED" == "false" ]; then
            echo "⚠️  Internal TLS is not enabled."
            echo "   Please enable internal TLS with a valid Cluster Issuer."
            echo "   You can check the /deployment-guide/scripts/internal-tls for guidance."
            return 1
        fi
    fi

    echo "✅ Internal TLS is enabled."
}

function check_rwx_storage() {
    if [ -z "$SHARED_STORAGECLASS" ]; then
        ask "SHARED_STORAGECLASS" "Specify the Kubernetes storage class for SHARED data (ReadWriteMany)" "standard" is_non_empty
    fi
    
    if ! kubectl get sc "${SHARED_STORAGECLASS}" &>/dev/null; then
        echo "❌ Storage Class (RWX) '${SHARED_STORAGECLASS}' not found."
        return 1
    fi

    echo "🔍 Checking support for ReadWriteMany persistent volumes (takes a few seconds)..."
    
    # Check if the storage class supports ReadWriteMany access mode
    local access_modes
    access_modes=$(kubectl get sc "${SHARED_STORAGECLASS}" -o jsonpath='{.allowVolumeExpansion}' 2>/dev/null)
    
    # Create a test PVC (with associated workload) to verify RWX support
    local test_pvc_name="rwx-test-pvc-$(date +%s)"
    local test_manifest="/tmp/${test_pvc_name}.yaml"
    
    cat > "${test_manifest}" << EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pvc-consumer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pvc-consumer
  template:
    metadata:
      labels:
        app: pvc-consumer
    spec:
      containers:
        - name: busybox
          image: busybox
          command: ["sleep", "3600"]
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${test_pvc_name}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${test_pvc_name}
  namespace: default
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: ${SHARED_STORAGECLASS}
EOF

    if kubectl apply -f "${test_manifest}" &>/dev/null; then

        # Wait for the deployment to be ready - which goes a long way to proving the PVC is usable
        # Also check the PVC status directly
        local pvc_status="Unbound"
        if kubectl rollout status deployment/pvc-consumer --timeout=20s &>/dev/null; then
            pvc_status=$(kubectl get pvc "${test_pvc_name}" -o jsonpath='{.status.phase}' 2>/dev/null)
        fi
        
        # Cleanup test PVC
        kubectl delete -f "${test_manifest}" &>/dev/null
        rm -f "${test_manifest}"

        
        if [[ "$pvc_status" == "Bound" ]]; then
            echo "✅ Storage Class (RWX) '${SHARED_STORAGECLASS}' supports ReadWriteMany access mode."
            return 0
        else
            echo "❌ Storage Class '${SHARED_STORAGECLASS}' does not support ReadWriteMany access mode."
            echo "Sometimes this shows up as a False Negative, if you are sure the storage class supports RWX, please ignore this message."
            echo "   PVC test failed with status: ${pvc_status}"
            return 1
        fi
    else
        rm -f "${test_manifest}"
        echo "❌ Failed to create test PVC for storage class '${SHARED_STORAGECLASS}'."
        echo "   This may indicate the storage class doesn't support ReadWriteMany."
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
