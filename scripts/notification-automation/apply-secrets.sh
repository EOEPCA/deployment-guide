#!/bin/bash

source ../common/utils.sh

# Make sure the notifications namespace exists before creating secrets in it.
kubectl get namespace notifications >/dev/null 2>&1 || \
    kubectl create namespace notifications

if [ "$NA_ENABLE_EMAILER" = "yes" ]; then
    echo "Applying SMTP credentials secret..."
    kubectl create secret generic notification-automation-smtp \
        --namespace notifications \
        --from-literal=username="$NA_SMTP_USER" \
        --from-literal=password="$NA_SMTP_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
fi

echo "Secrets applied."