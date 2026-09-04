#!/usr/bin/env bash

source ./oapip-utils.sh

echo ""
echo "Unauthenticated request to protected processes endpoint: (should redirect to the IAM login page)"
curl -I -s -D - "${HTTP_SCHEME}://zoo.${INGRESS_HOST}/${OAPIP_USER}/ogc-api/processes" \
  | awk '
      /^HTTP/ {code=$2}
      tolower($1) ~ /^location:/ {loc=$2}
      END {
        print "HTTP_CODE: " code
        print "LOCATION: " loc
      }
    '

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