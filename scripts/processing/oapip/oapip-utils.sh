#!/usr/bin/env bash

source ../../common/utils.sh

if [ "$OIDC_OAPIP_ENABLED" == "true" ]; then

    if [ -z "${OAPIP_USER}" -o -z "${OAPIP_PASSWORD}" ]; then
        ask_temp "OAPIP_USER" "Enter the username" "${KEYCLOAK_TEST_USER:-eoepcauser}"
        ask_temp "OAPIP_PASSWORD" "Enter the password for the user" "${KEYCLOAK_TEST_PASSWORD:-eoepcapassword}"
    fi

    ACCESS_TOKEN=$(
        curl --silent --show-error \
            -X POST \
            -d "username=${OAPIP_USER}" \
            --data-urlencode "password=${OAPIP_PASSWORD}" \
            -d "grant_type=password" \
            -d "client_id=${OAPIP_CLIENT_ID}" \
            -d "client_secret=${OAPIP_CLIENT_SECRET}" \
            "https://${KEYCLOAK_HOST}/realms/${REALM}/protocol/openid-connect/token" |
            jq -r '.access_token'
    )
    echo "Got access token: ${ACCESS_TOKEN:0:10}...${ACCESS_TOKEN: -10}"

    export OAPIP_USER
    export OAPIP_PASSWORD
    export ACCESS_TOKEN
    export OAPIP_AUTH_HEADER="Authorization: Bearer ${ACCESS_TOKEN}"

else

    export OAPIP_USER="eoepca"
    export ACCESS_TOKEN=""
    export OAPIP_AUTH_HEADER=""

fi
