#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh

echo "Applying Kubernetes secrets..."

kubectl create namespace gitlab --dry-run=client -oyaml | kubectl apply -f -
kubectl create namespace sharinghub --dry-run=client -oyaml | kubectl apply -f -

kubectl apply -f mlflow/generated-pvc.yaml

kubectl create secret generic gitlab-storage-config \
  --from-file=config=gitlab/storage.config \
  --namespace gitlab \
  --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic object-storage \
  --from-file=connection=gitlab/lfs-s3.yaml \
  --namespace gitlab \
  --dry-run=client -oyaml | kubectl apply -f -

# OIDC secrets
if [ "$MLOPS_OIDC_ENABLED" == "true" ]; then
  kubectl create secret generic openid-connect \
    --from-file=provider=gitlab/provider.yaml \
    --namespace gitlab \
    --dry-run=client -oyaml | kubectl apply -f -
fi

# SharingHub secrets
kubectl create secret generic sharinghub \
  --from-literal=session-secret-key="$SHARINGHUB_SESSION_SECRET" \
  --namespace sharinghub \
  --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic sharinghub-s3 \
  --from-literal access-key="$S3_ACCESS_KEY" \
  --from-literal secret-key="$S3_SECRET_KEY" \
  --namespace sharinghub \
  --dry-run=client -oyaml | kubectl apply -f -

# MLflow SharingHub secrets
kubectl create secret generic mlflow-sharinghub \
  --from-literal=secret-key="$MLFLOW_SECRET_KEY" \
  --namespace sharinghub --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic mlflow-sharinghub-s3 \
  --from-literal access-key-id="$S3_ACCESS_KEY" \
  --from-literal secret-access-key="$S3_SECRET_KEY" \
  --namespace sharinghub \
  --dry-run=client -oyaml | kubectl apply -f -

kubectl create secret generic mlflow-sharinghub-postgres \
  --from-literal=password="$MLFLOW_POSTGRES_PASSWORD" \
  --from-literal=postgres-password="$MLFLOW_POSTGRES_PASSWORD" \
  --namespace sharinghub \
  --dry-run=client -oyaml | kubectl apply -f -


echo "✅ Secrets applied."
