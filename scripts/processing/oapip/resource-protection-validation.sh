source ../../common/utils.sh

ask_temp "USER_NAME" "Enter the username to add to the group" "eoepcauser"
ask_temp "USER_PASSWORD" "Enter the password for the user" "eoepcauser"

TOKEN=$(curl --silent --show-error \
    -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${USER_NAME}" \
    -d "password=${USER_PASSWORD}" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" \
    "https://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" | jq -r '.access_token')

echo ""
echo "❌ Request sent without token:"
curl "https://zoo.wo3.apx.develop.eoepca.org/ogc-api/jobs"

echo ""
echo "✅ Request sent with token:"
curl -H "Authorization: Bearer $TOKEN" \
    "https://zoo.wo3.apx.develop.eoepca.org/ogc-api/jobs"
