source ./oapip-utils.sh

echo ""
echo "❌ Request sent without token:"
curl "https://zoo.${INGRESS_HOST}/${OAPIP_USER}/ogc-api/processes"

echo ""
echo "✅ Request sent with token:"
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/json" \
    "https://zoo.${INGRESS_HOST}/${OAPIP_USER}/ogc-api/processes"

echo ""
echo "✅ Request sent with token:"
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Accept: application/json" \
    "https://zoo.${INGRESS_HOST}/${OAPIP_USER}/ogc-api/jobs"
