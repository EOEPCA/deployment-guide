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
NAMESPACE="um"

ingress() {
  cat - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: ${NAMESPACE}
  name: identity-dummy-service
  annotations:
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
    nginx.ingress.kubernetes.io/configuration-snippet: |
      auth_request /auth;
      # Preflighted requests
      if (\$request_method = OPTIONS ) {
        return 200;
      }
      add_header Access-Control-Allow-Origin \$http_origin always;
      add_header Access-Control-Allow-Methods "*";
      add_header Access-Control-Allow-Headers "Authorization, Origin, Content-Type";
    nginx.ingress.kubernetes.io/server-snippet: |
      location ^~ /auth {
        internal;
        proxy_pass http://identity-gatekeeper.um.svc.cluster.local:3000/\$request_uri;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Method \$request_method;
        proxy_set_header X-Forwarded-URI \$request_uri;
        proxy_busy_buffers_size 64k;
        proxy_buffers 8 32k;
        proxy_buffer_size 32k;
      }
spec:
  ingressClassName: nginx
  rules:
    - host: identity.dummy-service.${domain}
      http:
        paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: dummy-service
                port:
                  number: 80
  tls:
    - hosts:
        - identity.dummy-service.${demo}
      secretName: identity-dummy-service-tls
EOF
}

databasePVC | kubectl ${ACTION_KUBECTL} -f -
