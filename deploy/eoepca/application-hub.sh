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
  helmChart
  secret
}

values() {
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
  ingress:
    enabled: true
  fullnameOverride: "application-hub"
  hub:

    extraEnv: 
        JUPYTERHUB_ENV: "dev"
        JUPYTERHUB_SINGLE_USER_IMAGE: "eoepca/pde-container:1.0.3"
        OAUTH_CALLBACK_URL: https://applicationhub.${domain}/hub/oauth_callback
        OAUTH2_USERDATA_URL: https://auth.${domain}/oxauth/restv1/userinfo
        OAUTH2_TOKEN_URL: https://auth.${domain}/oxauth/restv1/token
        OAUTH2_AUTHORIZE_URL: https://auth.${domain}/oxauth/restv1/authorize
        OAUTH_LOGOUT_REDIRECT_URL: "https://applicationhub.${domain}"
        OAUTH2_USERNAME_KEY: "user_name"
        STORAGE_CLASS: "${APPLICATION_HUB_STORAGE}"
        RESOURCE_MANAGER_WORKSPACE_PREFIX: "guide-user"

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
      #name: jupyterhub/k8s-hub
      #tag: "2.0.0"
      name: eoepca/application-hub
      tag: "1.0.0"
      pullPolicy: Always
      pullSecrets: []

    db:
      type: sqlite-pvc
      upgrade:
      pvc:
        annotations: {}
        selector: {}
        accessModes:
          - ReadWriteOnce
        storage: 1Gi
        subPath:
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

EOF
}

helmChart() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall application-hub
  else
    values | helm ${ACTION_HELM} application-hub application-hub -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 2.0.47
  fi
}

# Secret for Jupyter Hub access
secret() {
  kubectl -n "${NAMESPACE}" create secret generic application-hub-secrets \
    --from-literal=JUPYTERHUB_CRYPT_KEY="$(openssl rand -hex 32)" \
    --from-literal=OAUTH_CLIENT_ID="$(cat client-apphub.yaml | grep client-id | cut -d\  -f2)" \
    --from-literal=OAUTH_CLIENT_SECRET="$(cat client-apphub.yaml | grep client-secret | cut -d\  -f2)" \
    --dry-run=client -oyaml | kubectl ${ACTION_KUBECTL} -f -
}

main "$@"
