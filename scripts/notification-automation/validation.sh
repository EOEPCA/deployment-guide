#!/bin/bash
source ../common/utils.sh
source ../common/validation-utils.sh

echo "Validating Notification and Automation deployment..."

# Knative Operator (installed by the BB chart into the notifications namespace)
check_deployment_ready "notifications" "knative-operator"
check_deployment_ready "notifications" "operator-webhook"

# Knative Serving control plane
check_deployment_ready "knative-serving" "controller"
check_deployment_ready "knative-serving" "webhook"
check_deployment_ready "knative-serving" "activator"
check_deployment_ready "knative-serving" "autoscaler"
check_deployment_ready "knative-serving" "autoscaler-hpa"

# Kourier ingress for Knative
check_deployment_ready "knative-serving" "net-kourier-controller"
check_deployment_ready "knative-serving" "3scale-kourier-gateway"
check_service_exists "knative-serving" "kourier"

# Knative Eventing control plane
check_deployment_ready "knative-eventing" "eventing-controller"
check_deployment_ready "knative-eventing" "eventing-webhook"
check_deployment_ready "knative-eventing" "imc-controller"
check_deployment_ready "knative-eventing" "imc-dispatcher"
check_deployment_ready "knative-eventing" "mt-broker-controller"
check_deployment_ready "knative-eventing" "mt-broker-filter"
check_deployment_ready "knative-eventing" "mt-broker-ingress"

# Kafka, only if it was deployed and the cluster came up
if [ "$NA_ENABLE_KAFKA" = "yes" ] && kubectl get kafka kafka-cluster -n notifications >/dev/null 2>&1; then
    check_pods_running "notifications" "strimzi.io/cluster=kafka-cluster" 1
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