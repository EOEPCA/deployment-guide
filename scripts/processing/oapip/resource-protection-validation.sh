source ./oapip-utils.sh

echo ""
echo "❌ Request sent without token:"
curl "https://zoo.wo3.apx.develop.eoepca.org/ogc-api/processes"

echo ""
echo "✅ Request sent with token:"
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://zoo.wo3.apx.develop.eoepca.org/ogc-api/processes"

echo ""
echo "✅ Request sent with token:"
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://zoo.wo3.apx.develop.eoepca.org/ogc-api/jobs"
