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
NAMESPACE="rm"

main() {
  configYaml | kubectl ${ACTION_KUBECTL} -f -
  rbacYaml | kubectl ${ACTION_KUBECTL} -f -
  deploymentYaml | kubectl ${ACTION_KUBECTL} -f -
  serviceYaml | kubectl ${ACTION_KUBECTL} -f -
  ingressYaml | kubectl ${ACTION_KUBECTL} -f -
}

configYaml() {
  cat - <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: bucket-operator
  namespace: ${NAMESPACE}
data:
  application.yaml: |-
    logging:
      level:
        root: INFO
        eoepca: DEBUG
    management:
      endpoints:
        web:
          exposure:
            include: info, health, prometheus
    k8s:
      namespace: ${NAMESPACE}
      cluster: eoepca
EOF
}

rbacYaml() {
  cat - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bucket-operator
  namespace: ${NAMESPACE}
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rm-bucket-operator
subjects:
- kind: ServiceAccount
  name: bucket-operator
  namespace: ${NAMESPACE}
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
}

deploymentYaml() {
  cat - <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bucket-operator
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/instance: bucket-operator
    app.kubernetes.io/name: bucket-operator
spec:
  strategy:
    rollingUpdate:
      maxUnavailable: 0
    type: RollingUpdate
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: bucket-operator
      app.kubernetes.io/name: bucket-operator
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: "/actuator/prometheus"
        prometheus.io/port: "8080"
      labels:
        app.kubernetes.io/instance: bucket-operator
        app.kubernetes.io/name: bucket-operator
    spec:
      serviceAccountName: bucket-operator
      containers:
      - name: bucket-operator
        image: 'eoepca/rm-bucket-operator:1.0.0'
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          timeoutSeconds: 2
          periodSeconds: 3
          failureThreshold: 1
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 120
          timeoutSeconds: 2
          periodSeconds: 8
          failureThreshold: 1
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: '${NAMESPACE}'
        - name: OS_USERNAME
          value: '${OS_USERNAME}'
        - name: OS_PASSWORD
          value: '${OS_PASSWORD}'
        - name: OS_DOMAINNAME
          value: '${OS_DOMAINNAME}'
        - name: OS_MEMBERROLEID
          value: '${OS_MEMBERROLEID}'
        - name: OS_SERVICEPROJECTID
          value: '${OS_SERVICEPROJECTID}'
        - name: USER_EMAIL_PATTERN
          value: '${USER_EMAIL_PATTERN}'
        resources:
          limits:
            cpu: 0.5
            memory: 0.5Gi
          requests:
            cpu: 0.2
            memory: 256Mi
        # imagePullPolicy: Always
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      schedulerName: default-scheduler
EOF
}

serviceYaml() {
  cat - <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: bucket-operator
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/instance: bucket-operator
    app.kubernetes.io/name: bucket-operator
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/instance: bucket-operator
    app.kubernetes.io/name: bucket-operator
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: http
EOF
}

ingressYaml() {
  cat - <<EOF
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: bucket-operator
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/instance: bucket-operator
    app.kubernetes.io/name: bucket-operator
  annotations:
    cert-manager.io/cluster-issuer: ${TLS_CLUSTER_ISSUER}
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
spec:
  tls:
    - hosts:
        - bucket-operator.${domain}
      secretName: bucket-operator-tls
  rules:
    - host: bucket-operator.${domain}
      http:
        paths:
          - path: /
            backend:
              serviceName: bucket-operator
              servicePort: http
EOF
}

main "$@"
