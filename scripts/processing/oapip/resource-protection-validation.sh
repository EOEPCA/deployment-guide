#!/usr/bin/env bash

source ./oapip-utils.sh

echo ""
echo "Unauthenticated request to protected processes endpoint:"
CHECK_STATUS=$(
  curl --silent --show-error --output /dev/null --write-out "%{http_code}" \
    "${HTTP_SCHEME}://zoo.${INGRESS_HOST}/${OAPIP_USER}/ogc-api/processes"
)
echo "HTTP ${CHECK_STATUS}"

echo ""
echo "Authenticated request to protected processes endpoint:"
curl --silent --show-error \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    "${HTTP_SCHEME}://zoo.${INGRESS_HOST}/${OAPIP_USER}/ogc-api/processes" | jq

echo ""
echo "Authenticated request to jobs endpoint:"
curl --silent --show-error \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    "${HTTP_SCHEME}://zoo.${INGRESS_HOST}/${OAPIP_USER}/ogc-api/jobs" | jq