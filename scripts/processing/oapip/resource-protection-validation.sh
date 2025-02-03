source ./oapip-utils.sh

echo ""
echo "❌ Request sent without token:"
curl "https://zoo.${INGRESS_HOST}/ogc-api/processes"

echo ""
echo "✅ Request sent with token:"
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://zoo.${INGRESS_HOST}/ogc-api/processes"

echo ""
echo "✅ Request sent with token:"
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://zoo.${INGRESS_HOST}/ogc-api/jobs"
