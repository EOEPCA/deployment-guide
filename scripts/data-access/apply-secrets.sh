kubectl create namespace data-access --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic data-access \
    --from-literal=AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
    --namespace="data-access" \
    --dry-run=client -o yaml | kubectl apply -f -
