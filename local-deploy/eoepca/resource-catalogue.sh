#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source ../cluster/functions
configureAction "$1"
initIpDefaults

domain="${2:-${default_domain}}"

values() {
  cat - <<EOF
global:
  namespace: rm
ingress:
  name: resource-catalogue-open
  host: resource-catalogue-open.${domain}
  tls_host: resource-catalogue-open.${domain}
  tls_secret_name: resource-catalogue-open-tls
db:
  volume_storage_type: standard
pycsw:
  # image:
  #   pullPolicy: Always
  #   tag: "eoepca-0.9.0"
  config:
    server:
      url: https://resource-catalogue.${domain}/
    metadata:
      identification_title: pycsw Geospatial Catalogue
      identification_abstract: pycsw is an OGC CSW server implementation written in Python
      identification_keywords: catalogue,discovery,metadata
      identification_keywords_type: theme
      identification_fees: None
      identification_accessconstraints: None
      provider_name: Organization Name
      provider_url: https://pycsw.org/
      contact_name: Lastname, Firstname
      contact_position: Position Title
      contact_address: Mailing Address
      contact_city: City
      contact_stateorprovince: Administrative Area
      contact_postalcode: Zip or Postal Code
      contact_country: Country
      contact_phone: +xx-xxx-xxx-xxxx
      contact_fax: +xx-xxx-xxx-xxxx
      contact_email: Email Address
      contact_url: Contact URL
      contact_hours: Hours of Service
      contact_instructions: During hours of service.  Off on weekends.
      contact_role: pointOfContact
    inspire:
      enabled: "true"
      languages_supported: eng,gre
      default_language: eng
      date: YYYY-MM-DD
      gemet_keywords: Utility and governmental services
      conformity_service: notEvaluated
      contact_name: Organization Name
      contact_email: Email Address
      temp_extent: YYYY-MM-DD/YYYY-MM-DD
EOF
}

if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace rm uninstall resource-catalogue
else
  values | helm ${ACTION_HELM} resource-catalogue rm-resource-catalogue -f - \
    --repo https://eoepca.github.io/helm-charts \
    --namespace rm --create-namespace \
    --version 1.0.0
fi
