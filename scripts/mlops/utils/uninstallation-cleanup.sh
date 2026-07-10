
kubectl delete secrets -l app=gitlab -n gitlab
kubectl delete secrets gitlab-secrets gitlab-storage-config object-storage openid-connect -n gitlab
kubectl delete secrets -n sharinghub sharinghub sharinghub-oidc sharinghub-s3 mlflow-sharinghub mlflow-sharinghub-s3 mlflow-sharinghub-postgres

# mlflow-postgres is a plain kubectl-applied Deployment/Service, not Helm-managed.
# Delete it before its PVC - otherwise the PVC-protection finalizer blocks on the
# still-running pod and `kubectl delete pvc` hangs.
kubectl delete deployment mlflow-postgres -n sharinghub
kubectl delete service mlflow-postgres -n sharinghub

kubectl delete pvc -n gitlab repo-data-gitlab-gitaly-0 redis-data-gitlab-redis-master-0 data-gitlab-postgresql-0
kubectl delete pvc -n sharinghub mlflow-sharinghub-store-pvc mlflow-postgres-pvc
