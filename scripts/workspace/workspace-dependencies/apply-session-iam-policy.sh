#!/bin/bash
# Plain shell script, not a gomplate template: Kyverno's own {{ }} JMESPath
# expressions below would collide with gomplate's {{ }} delimiters. Only the
# ${VAR} shell variables are substituted here.

source ../common/utils.sh
source "$HOME/.eoepca/state"

cat <<EOF | kubectl apply -f -
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: workspace-session-iam
spec:
  admission: true
  background: false
  rules:
    - name: generate-apisix-oidc-plugin-config-for-workspace-sessions
      match:
        any:
          - resources:
              kinds:
                - Ingress
              selector:
                matchLabels:
                  training.educates.dev/application: workshop
                  training.educates.dev/component: session
      preconditions:
        all:
          - key: "{{ request.object.spec.ingressClassName || '' }}"
            operator: Equals
            value: apisix
          - key: "{{ (request.object.spec.rules || [])[?host != null && ends_with(host, '.${INGRESS_HOST}')] | length(@) }}"
            operator: GreaterThan
            value: 0
          - key: "{{ request.object.metadata.labels.\"training.educates.dev/environment.name\" || '' }}"
            operator: NotEquals
            value: ""
      generate:
        apiVersion: apisix.apache.org/v2
        kind: ApisixPluginConfig
        name: "workspace-session-oidc-{{ request.object.metadata.labels.\"training.educates.dev/environment.name\" }}"
        namespace: "{{ request.namespace }}"
        synchronize: false
        data:
          metadata:
            labels:
              training.educates.dev/application: workshop
              training.educates.dev/component: session
              training.educates.dev/environment.name: "{{ request.object.metadata.labels.\"training.educates.dev/environment.name\" }}"
          spec:
            plugins:
              - name: openid-connect
                enable: true
                config:
                  discovery: "${HTTP_SCHEME}://${KEYCLOAK_HOST}/realms/${REALM}/.well-known/openid-configuration"
                  use_jwks: true
                  bearer_only: false
                  set_access_token_header: true
                  access_token_in_authorization_header: true
                  set_id_token_header: false
                  set_userinfo_header: false
                  session:
                    secret: "{{ random('[A-Za-z0-9]{32}') }}"
                secretRef: workspace-api-keycloak-client
    - name: add-apisix-oidc-plugin-config-for-workspace-sessions
      match:
        any:
          - resources:
              kinds:
                - Ingress
              selector:
                matchLabels:
                  training.educates.dev/application: workshop
                  training.educates.dev/component: session
      preconditions:
        all:
          - key: "{{ request.object.spec.ingressClassName || '' }}"
            operator: Equals
            value: apisix
          - key: "{{ (request.object.spec.rules || [])[?host != null && ends_with(host, '.${INGRESS_HOST}')] | length(@) }}"
            operator: GreaterThan
            value: 0
          - key: "{{ request.object.metadata.labels.\"training.educates.dev/environment.name\" || '' }}"
            operator: NotEquals
            value: ""
      mutate:
        patchStrategicMerge:
          metadata:
            annotations:
              +(k8s.apisix.apache.org/plugin-config-name): "workspace-session-oidc-{{ request.object.metadata.labels.\"training.educates.dev/environment.name\" }}"
              +(k8s.apisix.apache.org/enable-websocket): "true"
EOF
