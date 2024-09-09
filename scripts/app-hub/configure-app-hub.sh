#!/bin/bash

echo "Configuring the App Hub..."
source ../common/utils.sh

# Minimal user input for quick setup
ask APP_HUB_HOST "Enter the public URL for the App Hub (e.g., applicationhub.example.com):"
ask APP_HUB_TLS_SECRET "Specify the TLS secret name for the App Hub (default 'applicationhub-tls'):" "applicationhub-tls"
ask DB_STORAGE_CLASS "Specify the Kubernetes storage class for database persistence:" "managed-nfs-storage-retain"
ask CLUSTER_ISSUER "Specify the cert-manager cluster issuer for TLS certificates:" "letsencrypt-prod"
ask INGRESS_CLASS "Specify the ingress class for the Resource Catalogue:" "nginx"

# Hardcoded, not secure for production, base64-encoded 32 byte encryption key
DEFAULT_JUPYTERHUB_CRYPT_KEY=$(openssl rand -base64 32)

# Generate values.yaml with both user input and defaults
cat >./generated-values.yaml <<EOF
ingress:
  enabled: true
  className: ${INGRESS_CLASS}
  annotations: {}
  hosts:
    - host: ${APP_HUB_HOST}
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls:
    - secretName: ${APP_HUB_TLS_SECRET}
      hosts:
      - ${APP_HUB_HOST}
  clusterIssuer: ${CLUSTER_ISSUER}

jupyterhub:
  fullnameOverride: "application-hub"
  hub:
    extraEnv:
      JUPYTERHUB_ENV: "dev"
      JUPYTERHUB_SINGLE_USER_IMAGE: "eoepca/pde-container:1.0.3"
      APP_HUB_NAMESPACE: "app-hub"
      STORAGE_CLASS: "standard"
      RESOURCE_MANAGER_WORKSPACE_PREFIX: "ws"

      JUPYTERHUB_CRYPT_KEY: "${DEFAULT_JUPYTERHUB_CRYPT_KEY}"

    image:
      pullPolicy: Always

    db:
      pvc:
        storageClassName: ${DB_STORAGE_CLASS}

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
        cpu_limit: 4
        mem_limit: "8G"
nodeSelector:
  key: "node-role.kubernetes.io/master"
  value: "true"
EOF

echo "Configuration file generated: ./generated-values.yaml"