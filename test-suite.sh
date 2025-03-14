#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

function onExit() {
  cd "${ORIG_DIR}"
}
trap "onExit" EXIT

#-------------------------------------------------------------------------------
# Check docker command is available
#-------------------------------------------------------------------------------
if ! hash docker 2>/dev/null; then
  echo "ERROR - docker is required" 1>&2
  exit 1
fi

#-------------------------------------------------------------------------------
# Generate the pytest env
#-------------------------------------------------------------------------------
source ~/.eoepca/state
cat <<EOF > ~/.eoepca/pytest.env
DOMAIN=${INGRESS_HOST}
SCHEME=${HTTP_SCHEME}
KEYCLOAK=${KEYCLOAK_HOST}
EOAPI=eoapi.${INGRESS_HOST}
MLOPS=sharinghub.${INGRESS_HOST}
REALM=${REALM}
TEST_USER=${KEYCLOAK_TEST_USER}
TEST_PASSWORD=${KEYCLOAK_TEST_PASSWORD}
ADMIN_CLIENT_ID=admin-cli
OAPIP_CLIENT_ID=${OAPIP_CLIENT_ID}
OAPIP_CLIENT_SECRET=${OAPIP_CLIENT_SECRET}
EOF

#-------------------------------------------------------------------------------
# Run the test suite via docker
#-------------------------------------------------------------------------------
PYTEST_OPTIONS="${@}"
mkdir -p ${ORIG_DIR}/.pytest_cache
docker run --rm -t -u $UID:$GID \
  -e target=eoepca \
  -v ~/.eoepca/pytest.env:/work/test/.env.eoepca \
  -v ${ORIG_DIR}/.pytest_cache:/work/.pytest_cache \
  -v ${ORIG_DIR}:/work/out \
  eoepca/system-test \
  pytest test ${PYTEST_OPTIONS} -v --junit-xml=out/test-report.xml
