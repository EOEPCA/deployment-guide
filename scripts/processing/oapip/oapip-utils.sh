#!/usr/bin/env bash

source ../../common/utils.sh

ask_temp "USER_NAME" "Enter the username" "username"
ask_temp "USER_PASSWORD" "Enter the password for the user" "password"

ACCESS_TOKEN=$(
    curl --silent --show-error \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${USER_NAME}" \
        -d "password=${USER_PASSWORD}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" \
        "https://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" |
        jq -r '.access_token'
)

echo ""
echo "Got access token: ${ACCESS_TOKEN:0:10}...${ACCESS_TOKEN: -10}"

export ACCESS_TOKEN=$ACCESS_TOKEN
export OAPIP_AUTH_HEADER="Authorization: Bearer ${ACCESS_TOKEN}"
