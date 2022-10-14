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
NAMESPACE="pde"

main() {
  helmChart
  secret
}

# Secret for jupyterhub access
secret() {
  kubectl -n "${NAMESPACE}" create secret generic jupyterhub-secrets \
    --from-literal=JUPYTERHUB_CRYPT_KEY="$(openssl rand -hex 32)" \
    --from-literal=OAUTH_CLIENT_ID="$(cat client.yaml | grep client-id | cut -d\  -f2)" \
    --from-literal=OAUTH_CLIENT_SECRET="$(cat client.yaml | grep client-secret | cut -d\  -f2)" \
    --dry-run=client -oyaml | kubectl ${ACTION_KUBECTL} -f -
}

values() {
  cat - <<EOF
hub:
  db:
    pvc:
      storageClassName: ${PDE_STORAGE}
  extraEnv:
    OAUTH_CALLBACK_URL: "https://pde.${domain}/hub/oauth_callback"
    OAUTH2_USERDATA_URL: "https://auth.${domain}/oxauth/restv1/userinfo"
    OAUTH2_TOKEN_URL: "https://auth.${domain}/oxauth/restv1/token"
    OAUTH2_AUTHORIZE_URL: "https://auth.${domain}/oxauth/restv1/authorize"
    OAUTH_LOGOUT_REDIRECT_URL: "https://auth.${domain}/oxauth/restv1/end_session?post_logout_redirect_uri=https://pde.${domain}"
    STORAGE_CLASS: "${PDE_STORAGE}"
ingress:
  enabled: true
  annotations:
    eoepca: guide-cluster
    kubernetes.io/ingress.class: nginx
    ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
  hosts:
    - host: pde.${domain}
      paths:
        - path: /
  tls:
    - hosts:
        - pde.${domain}
      secretName: pde-tls
EOF
}

helmChart() {
  if [ "${ACTION_HELM}" = "uninstall" ]; then
    helm --namespace "${NAMESPACE}" uninstall pde
  else
    values | helm ${ACTION_HELM} pde jupyterhub -f - \
      --repo https://eoepca.github.io/helm-charts \
      --namespace "${NAMESPACE}" --create-namespace \
      --version 1.1.12
  fi
}

main "$@"
