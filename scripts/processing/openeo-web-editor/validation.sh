#!/bin/bash
source ../../common/utils.sh
source ../../common/validation-utils.sh
source "$HOME/.eoepca/state"

check_deployment_ready "openeo-web-editor" "openeo-web-editor"
check_service_exists "openeo-web-editor" "openeo-web-editor"
check_url_status_code "${HTTP_SCHEME}://${OPENEO_WEB_EDITOR_HOST}" "200"

echo
echo "All Resources in 'openeo-web-editor' namespace:"
echo
kubectl get all -n openeo-web-editor
