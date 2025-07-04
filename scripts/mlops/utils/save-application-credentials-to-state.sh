# Load utility functions
source ../common/utils.sh

ask "GITLAB_APP_ID" "Enter the SharingHub Application ID" "" is_non_empty
ask "GITLAB_APP_SECRET" "Enter the SharingHub Secret" "" is_non_empty

kubectl create secret generic sharinghub-oidc \
  --from-literal=client-id="$GITLAB_APP_ID" \
  --from-literal=client-secret="$GITLAB_APP_SECRET" \
  --namespace sharinghub \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Successfully saved variables to state and created the secret in the sharinghub namespace"
