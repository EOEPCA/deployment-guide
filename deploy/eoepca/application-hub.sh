#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source ../cluster/functions
configureAction "$1"
initIpDefaults

domain="${2:-${default_domain}}"
NAMESPACE="proc"

main() {
  deployService
  createSecret
  createClient
}

deployService() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall application-hub
  else
    serviceValues | helm ${ACTION_HELM} application-hub application-hub -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 2.0.55
  fi
}

serviceValues() {
  cat - <<EOF
ingress:
  enabled: true
  annotations: {}
  hosts:
    - host: applicationhub.${domain}
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: applicationhub-tls
      hosts:
      - applicationhub.${domain}
  clusterIssuer: "${TLS_CLUSTER_ISSUER}"

jupyterhub:
  fullnameOverride: "application-hub"
  hub:
    existingSecret: application-hub-secrets
    extraEnv: 
        JUPYTERHUB_ENV: "dev"
        JUPYTERHUB_SINGLE_USER_IMAGE: "eoepca/pde-container:1.0.3"
        OAUTH_CALLBACK_URL: $(httpScheme)://applicationhub.${domain}/hub/oauth_callback
        OAUTH2_USERDATA_URL: $(httpScheme)://identity.keycloak.${domain}/realms/master/protocol/openid-connect/userinfo
        OAUTH2_TOKEN_URL: $(httpScheme)://identity.keycloak.${domain}/realms/master/protocol/openid-connect/token
        OAUTH2_AUTHORIZE_URL: $(httpScheme)://identity.keycloak.${domain}/realms/master/protocol/openid-connect/auth
        OAUTH_LOGOUT_REDIRECT_URL: "$(httpScheme)://applicationhub.${domain}"
        OAUTH2_USERNAME_KEY: "preferred_username"
        STORAGE_CLASS: "${APPLICATION_HUB_STORAGE}"
        RESOURCE_MANAGER_WORKSPACE_PREFIX: "ws"

        JUPYTERHUB_CRYPT_KEY:
          valueFrom:
            secretKeyRef:
              name: application-hub-secrets
              key: JUPYTERHUB_CRYPT_KEY

        OAUTH_CLIENT_ID:
          valueFrom:
            secretKeyRef:
              name: application-hub-secrets
              key: OAUTH_CLIENT_ID
          
        OAUTH_CLIENT_SECRET:
          valueFrom:
            secretKeyRef:
              name: application-hub-secrets
              key: OAUTH_CLIENT_SECRET

    image:
      # name: eoepca/application-hub
      # tag: "1.2.0"
      pullPolicy: Always
      # pullSecrets: []

    db:
      pvc:
        storageClassName: ${APPLICATION_HUB_STORAGE}
  
  singleuser:
    image:
      name: jupyter/minimal-notebook
      tag: "2343e33dec46"
    profileList: 
    - display_name:  "Minimal environment"
      description: "To avoid too much bells and whistles: Python."
      default: "True"
    - display_name:  "EOEPCA profile"
      description: "Sample profile"
      kubespawner_override:
        cpu_limit": 4
        mem_limit": "8G"

nodeSelector:
  key: minikube.k8s.io/primary
  value: \"true\"

EOF
}

# Secret for Jupyter Hub access
createSecret() {
  kubectl -n "${NAMESPACE}" create secret generic application-hub-secrets \
    --from-literal=JUPYTERHUB_CRYPT_KEY="$(openssl rand -hex 32)" \
    --from-literal=OAUTH_CLIENT_ID="application-hub" \
    --from-literal=OAUTH_CLIENT_SECRET="changeme" \
    --dry-run=client -oyaml | kubectl ${ACTION_KUBECTL} -f -
}

createClient() {
  # Create the client
  ../bin/create-client \
    -a $(httpScheme)://identity.keycloak.${domain} \
    -i $(httpScheme)://identity-api.${domain} \
    -r "${IDENTITY_REALM}" \
    -u "${IDENTITY_SERVICE_ADMIN_USER}" \
    -p "${IDENTITY_SERVICE_ADMIN_PASSWORD}" \
    -c "${IDENTITY_SERVICE_ADMIN_CLIENT}" \
    --id=application-hub \
    --name="Application Hub OIDC Client" \
    --secret="${IDENTITY_SERVICE_DEFAULT_SECRET}" \
    --description="Client to be used by Application Hub for OIDC integration"
}

main "$@"
