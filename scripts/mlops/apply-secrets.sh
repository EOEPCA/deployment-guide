#!/bin/bash

# Load utility functions and state file
source ../common/utils.sh

echo "Applying Kubernetes secrets..."

kubectl create namespace gitlab
kubectl create namespace sharinghub

kubectl apply -f mlflow/generated-pvc.yaml

kubectl create secret generic gitlab-storage-config \
  --from-file=config=gitlab/storage.config \
  --namespace gitlab

kubectl create secret generic object-storage \
  --from-file=connection=gitlab/lfs-s3.yaml \
  --namespace gitlab

kubectl create secret generic openid-connect \
  --from-file=provider=gitlab/provider.yaml \
  --namespace gitlab

# SharingHub secrets
kubectl create secret generic sharinghub \
  --from-literal=session-secret-key="$SHARINGHUB_SESSION_SECRET" \
  --namespace sharinghub


kubectl create secret generic sharinghub-oidc \
  --from-literal=client-id="$GITLAB_APP_ID" \
  --from-literal=client-secret="$GITLAB_APP_SECRET" \
  --namespace sharinghub

kubectl create secret generic sharinghub-s3 \
  --from-literal access-key="$S3_ACCESS_KEY" \
  --from-literal secret-key="$S3_SECRET_KEY" \
  --namespace sharinghub

# MLflow SharingHub secrets
kubectl create secret generic mlflow-sharinghub \
  --from-literal=secret-key="$MLFLOW_SECRET_KEY" \
  --namespace sharinghub

kubectl create secret generic mlflow-sharinghub-s3 \
  --from-literal access-key-id="$S3_ACCESS_KEY" \
  --from-literal secret-access-key="$S3_SECRET_KEY" \
  --namespace sharinghub

echo "✅ Secrets applied."