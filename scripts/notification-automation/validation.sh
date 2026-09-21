#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh
set -e

echo "Validating Notification and Automation deployment..."

check_deployment_ready "knative-operator" "knative-operator"
check_deployment_ready "knative-operator" "operator-webhook"
kubectl get crd knativeservings.operator.knative.dev >/dev/null
kubectl get crd knativeeventings.operator.knative.dev >/dev/null

check_deployment_ready "knative-serving" "controller"
check_deployment_ready "knative-serving" "webhook"
check_deployment_ready "knative-serving" "activator"
check_deployment_ready "knative-serving" "autoscaler"
check_deployment_ready "knative-serving" "autoscaler-hpa"
check_deployment_ready "knative-serving" "net-kourier-controller"
check_deployment_ready "knative-serving" "3scale-kourier-gateway"
check_service_exists "knative-serving" "kourier"

check_deployment_ready "knative-eventing" "eventing-controller"
check_deployment_ready "knative-eventing" "eventing-webhook"
check_deployment_ready "knative-eventing" "imc-controller"
check_deployment_ready "knative-eventing" "imc-dispatcher"
check_deployment_ready "knative-eventing" "mt-broker-controller"
check_deployment_ready "knative-eventing" "mt-broker-filter"
check_deployment_ready "knative-eventing" "mt-broker-ingress"

check_deployment_ready "notifications" "notification-automation-webhook-source"
check_deployment_ready "notifications" "notification-automation-cloudevents-player"
check_service_exists "notifications" "notification-automation-webhook-source"
check_service_exists "notifications" "notification-automation-cloudevents-player"

kubectl wait --for=condition=Ready broker/default -n notifications --timeout=120s
kubectl wait --for=condition=Ready apiserversource/notification-automation-api-server-source -n notifications --timeout=120s
kubectl wait --for=condition=Ready sinkbinding/notification-automation-webhook-source-binding -n notifications --timeout=120s
kubectl wait --for=condition=Ready trigger/notification-automation-cloudevents-player-trigger -n notifications --timeout=120s
check_url_status_code "${HTTP_SCHEME}://webhooks.notifications.${INGRESS_HOST}/health" 200
check_url_status_code "${HTTP_SCHEME}://cloudevents-player.notifications.${INGRESS_HOST}" 200

if [ "$NA_ENABLE_EMAILER" = "yes" ]; then
    check_deployment_ready "notifications" "notification-automation-emailer"
    check_service_exists "notifications" "notification-automation-emailer"
fi

if [ "$NA_ENABLE_KAFKA" = "yes" ]; then
    kubectl wait --for=condition=Ready kafka/kafka-cluster -n notifications --timeout=300s
fi

echo
echo "All Resources:"
echo
echo "--- knative-serving ---"
kubectl get all -n knative-serving
echo
echo "--- knative-eventing ---"
kubectl get all -n knative-eventing
echo
echo "--- notifications ---"
kubectl get all -n notifications
echo
echo "✅ Notification and Automation validation succeeded."
