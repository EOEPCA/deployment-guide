#!/bin/bash

source ../common/utils.sh
echo "Configuring the Resource Health Building Block..."

ask "INTERNAL_CLUSTER_ISSUER" "Specify the cert-manager cluster issuer for internal TLS certificates" "eoepca-ca-clusterissuer" is_non_empty
ask "PERSISTENT_STORAGECLASS" "Specify the Kubernetes storage class for PERSISTENT data (ReadWriteOnce)" "local-path" is_non_empty
ask "INGRESS_HOST" "Enter the base domain name" "example.com" is_valid_domain
configure_cert

ask "RESOURCE_HEALTH_ENABLE_OIDC" "Enable OIDC protection for Resource Health? (yes/no)" "yes" is_yes_no

# Ingress-layer enforcement (ApisixRoute + openid-connect plugin) - no nginx equivalent here.
if [ "$RESOURCE_HEALTH_ENABLE_OIDC" = "yes" ] && [ "$INGRESS_CLASS" != "apisix" ]; then
    echo "❌ OIDC-protected Resource Health currently requires INGRESS_CLASS=apisix."
    echo "   Re-run the configuration and select APISIX, or set RESOURCE_HEALTH_ENABLE_OIDC=no."
    exit 1
fi

if [[ "$RESOURCE_HEALTH_ENABLE_OIDC" == "yes" ]]; then
    source ../common/prerequisite-utils.sh
    run_validation "check_crossplane_installed"

    ask "RESOURCE_HEALTH_CLIENT_ID" "Enter the Resource Health Keycloak Client ID" "resource-health" is_non_empty

    if [ -z "$RESOURCE_HEALTH_CLIENT_SECRET" ]; then
        RESOURCE_HEALTH_CLIENT_SECRET=$(generate_aes_key 32)
        add_to_state_file "RESOURCE_HEALTH_CLIENT_SECRET" "$RESOURCE_HEALTH_CLIENT_SECRET"
    fi
    echo ""
    echo "❗  Generated client secret for Resource Health."
    echo "   Please store this securely: $RESOURCE_HEALTH_CLIENT_SECRET"
    echo ""

    # Shared session-cookie encryption key for the APISIX openid-connect plugin.
    if [ -z "$RESOURCE_HEALTH_SESSION_SECRET" ]; then
        RESOURCE_HEALTH_SESSION_SECRET=$(generate_aes_key 32)
        add_to_state_file "RESOURCE_HEALTH_SESSION_SECRET" "$RESOURCE_HEALTH_SESSION_SECRET"
    fi

    if [ -z "$KEYCLOAK_HOST" ]; then
        ask "KEYCLOAK_HOST" "Enter the Keycloak full host domain excluding https (e.g., auth.example.com)" "auth.${INGRESS_HOST}" is_valid_domain
    fi

    if [ -z "$REALM" ]; then
        ask "REALM" "Enter the Keycloak realm" "eoepca" is_non_empty
    fi

    if [ -z "$KEYCLOAK_TEST_USER" ]; then
        ask "KEYCLOAK_TEST_USER" "Enter your Keycloak test user username" "eoepcauser" is_non_empty
    fi

    if [ -z "$KEYCLOAK_TEST_PASSWORD" ]; then
        ask "KEYCLOAK_TEST_PASSWORD" "Enter your Keycloak test user password" "" is_non_empty
    fi
fi

# The chart's alerting component is always deployed and crashloops without these
# set - safe placeholders keep it up if you don't want to wire up real SMTP.
ask "RESOURCE_HEALTH_ENABLE_ALERTING" "Enable email alerting for failed health checks? (yes/no)" "no" is_yes_no

if [ "$RESOURCE_HEALTH_ENABLE_ALERTING" == "yes" ]; then
    ask "RESOURCE_HEALTH_SMTP_HOST" "SMTP server host for alert emails" "smtp.gmail.com" is_non_empty
    ask "RESOURCE_HEALTH_SMTP_PORT" "SMTP server port" "465" is_non_empty
    ask "RESOURCE_HEALTH_FROM_EMAIL" "From-email address for alert emails" "noreply@example.com" is_non_empty
    ask "RESOURCE_HEALTH_FROM_EMAIL_PASSWORD" "Password/app-password for the from-email account" "" is_non_empty
    ask "RESOURCE_HEALTH_MAX_EMAILS_PER_DAY" "Maximum alert emails to send per day" "300" is_non_empty
else
    add_to_state_file "RESOURCE_HEALTH_SMTP_HOST" "${RESOURCE_HEALTH_SMTP_HOST:-smtp.example.com}"
    add_to_state_file "RESOURCE_HEALTH_SMTP_PORT" "${RESOURCE_HEALTH_SMTP_PORT:-465}"
    add_to_state_file "RESOURCE_HEALTH_FROM_EMAIL" "${RESOURCE_HEALTH_FROM_EMAIL:-noreply@example.com}"
    add_to_state_file "RESOURCE_HEALTH_FROM_EMAIL_PASSWORD" "${RESOURCE_HEALTH_FROM_EMAIL_PASSWORD:-disabled}"
    add_to_state_file "RESOURCE_HEALTH_MAX_EMAILS_PER_DAY" "0"
fi
export RESOURCE_HEALTH_SMTP_HOST RESOURCE_HEALTH_SMTP_PORT RESOURCE_HEALTH_FROM_EMAIL RESOURCE_HEALTH_FROM_EMAIL_PASSWORD RESOURCE_HEALTH_MAX_EMAILS_PER_DAY

if [ "$INGRESS_CLASS" == "apisix" ]; then
    gomplate -f "apisix/apisix-ingress-template.yaml" -o "$INGRESS_OUTPUT_PATH"
    if [ "$RESOURCE_HEALTH_ENABLE_OIDC" == "yes" ]; then
        gomplate -f "apisix/apisix-route-browser-auth-plugin-template.yaml" -o "apisix/plugin-browser-auth.yaml"
        gomplate -f "apisix/apisix-route-plugin-template.yaml" -o "apisix/plugin-api-auth.yaml"
    fi

elif [ "$INGRESS_CLASS" == "nginx" ]; then
    gomplate -f "nginx-ingress-template.yaml" -o "$INGRESS_OUTPUT_PATH" --datasource annotations="$GOMPLATE_DATASOURCE_ANNOTATIONS"
fi

gomplate -f "$TEMPLATE_PATH" -o "$OUTPUT_PATH"

if [ "$RESOURCE_HEALTH_ENABLE_OIDC" == "yes" ]; then
    gomplate -f "iam-template.yaml" -o "generated-iam.yaml"
    gomplate -f "keycloak-template.yaml" -o "generated-keycloak.yaml"
fi

echo "You can now proceed to deploy the Resource Health secrets."