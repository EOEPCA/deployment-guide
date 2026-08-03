#!/bin/bash

source ../common/utils.sh
echo "Configuring the Application Quality Building Block..."

ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for persistent data" "local-path" is_non_empty
ask "SHARED_STORAGECLASS" "Specify the Kubernetes storage class for shared/RWX data used by Calrissian" "${PERSISTENT_STORAGECLASS}" is_non_empty
configure_cert
ask "INTERNAL_CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for internal TLS certificates" "eoepca-ca-clusterissuer" is_non_empty

export APP_QUALITY_PUBLIC_HOST="${APP_QUALITY_PUBLIC_HOST:-application-quality.${INGRESS_HOST}}"
add_to_state_file "APP_QUALITY_PUBLIC_HOST" "${APP_QUALITY_PUBLIC_HOST}"
add_to_state_file "SHARED_STORAGECLASS" "${SHARED_STORAGECLASS}"

if ask_yes_no "Enable IAM/OIDC authentication?"; then
    export APP_QUALITY_ENABLE_IAM="true"

    # App-native OIDC, not an ingress-layer plugin, so this works under nginx too.
    ask "APP_QUALITY_CLIENT_ID" "Enter the OIDC client ID for Application Quality" "application-quality-bb" is_non_empty

    if [ -z "${APP_QUALITY_CLIENT_SECRET:-}" ]; then
        APP_QUALITY_CLIENT_SECRET="$(generate_aes_key 32)"
    fi

    add_to_state_file "APP_QUALITY_ENABLE_IAM" "${APP_QUALITY_ENABLE_IAM}"
    add_to_state_file "APP_QUALITY_CLIENT_ID" "${APP_QUALITY_CLIENT_ID}"
    add_to_state_file "APP_QUALITY_CLIENT_SECRET" "${APP_QUALITY_CLIENT_SECRET}"

    echo ""
    echo "Generated Application Quality client secret:"
    echo "${APP_QUALITY_CLIENT_SECRET}"
    echo ""

    gomplate -f "iam-template.yaml" -o "generated-iam.yaml"
else
    export APP_QUALITY_ENABLE_IAM="false"
    add_to_state_file "APP_QUALITY_ENABLE_IAM" "${APP_QUALITY_ENABLE_IAM}"
    echo ""
    echo "IAM/OIDC disabled. Application Quality will be deployed without authentication."
    echo ""
fi

export APP_QUALITY_ENABLE_NOTIFICATIONS="${APP_QUALITY_ENABLE_NOTIFICATIONS:-false}"
add_to_state_file "APP_QUALITY_ENABLE_NOTIFICATIONS" "${APP_QUALITY_ENABLE_NOTIFICATIONS}"

if ask_yes_no "Enable optional Grafana dashboards?"; then
    export APP_QUALITY_ENABLE_GRAFANA="true"
    echo ""
    echo "Grafana will be deployed with local admin login only; this guide does not configure Grafana OIDC SSO."
    echo ""
else
    export APP_QUALITY_ENABLE_GRAFANA="false"
fi
add_to_state_file "APP_QUALITY_ENABLE_GRAFANA" "${APP_QUALITY_ENABLE_GRAFANA}"

if ask_yes_no "Enable optional SonarQube deployment?"; then
    export APP_QUALITY_ENABLE_SONARQUBE="true"

    if [ "${INGRESS_CLASS:-}" = "nginx" ]; then
        echo "ERROR: SonarQube routing in this guide currently uses APISIX ApisixRoute."
        echo "Use APISIX or leave SonarQube disabled."
        exit 1
    fi

    APP_QUALITY_SONARQUBE_DB_PASSWORD="${APP_QUALITY_SONARQUBE_DB_PASSWORD:-$(generate_aes_key 32)}"
    APP_QUALITY_SONARQUBE_DB_POSTGRES_PASSWORD="${APP_QUALITY_SONARQUBE_DB_POSTGRES_PASSWORD:-$(generate_aes_key 32)}"
    APP_QUALITY_SONARQUBE_MONITORING_PASSCODE="${APP_QUALITY_SONARQUBE_MONITORING_PASSCODE:-$(generate_aes_key 32)}"

    add_to_state_file "APP_QUALITY_ENABLE_SONARQUBE" "${APP_QUALITY_ENABLE_SONARQUBE}"
    add_to_state_file "APP_QUALITY_SONARQUBE_DB_PASSWORD" "${APP_QUALITY_SONARQUBE_DB_PASSWORD}"
    add_to_state_file "APP_QUALITY_SONARQUBE_DB_POSTGRES_PASSWORD" "${APP_QUALITY_SONARQUBE_DB_POSTGRES_PASSWORD}"
    add_to_state_file "APP_QUALITY_SONARQUBE_MONITORING_PASSCODE" "${APP_QUALITY_SONARQUBE_MONITORING_PASSCODE}"
else
    export APP_QUALITY_ENABLE_SONARQUBE="false"
    add_to_state_file "APP_QUALITY_ENABLE_SONARQUBE" "${APP_QUALITY_ENABLE_SONARQUBE}"
fi

# Generate Application Quality Helm values
gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"

# Generate optional SonarQube Helm values and APISIX route
if [ "${APP_QUALITY_ENABLE_SONARQUBE:-false}" = "true" ]; then
    gomplate -f sonarqube-db-values-template.yaml -o generated-sonarqube-db-values.yaml
    gomplate -f sonarqube-values-template.yaml -o generated-sonarqube-values.yaml
    gomplate -f sonarqube-apisix-template.yaml -o generated-sonarqube-apisix.yaml
fi