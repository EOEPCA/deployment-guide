
kubectl delete secrets -l app=gitlab -n gitlab
kubectl delete secrets gitlab-secrets gitlab-storage-config object-storage openid-connect -n gitlab
kubectl delete secrets -n sharinghub sharinghub sharinghub-oidc sharinghub-s3 mlflow-sharinghub mlflow-sharinghub-s3
kubectl delete pvc -n gitlab repo-data-gitlab-gitaly-0 redis-data-gitlab-redis-master-0 data-gitlab-postgresql-0
helm uninstall gitlab