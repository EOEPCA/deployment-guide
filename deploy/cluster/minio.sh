#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

source functions
configureAction "$1"
initIpDefaults

domain="${2:-${default_domain}}"
NAMESPACE="rm"

values() {
  cat - <<EOF
existingSecret: minio-auth
replicas: 2

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: '600'
  path: /
  hosts:
    - minio.${domain}
  tls:
    - secretName: minio-tls
      hosts:
        - minio.${domain}

consoleIngress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: "${TLS_CLUSTER_ISSUER}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: '600'
  path: /
  hosts:
    - console.minio.${domain}
  tls:
  - secretName: minio-console-tls
    hosts:
      - console.minio.${domain}

resources:
  requests:
    memory: 1Gi

persistence:
  storageClass: ${MINIO_STORAGE}

buckets:
  - name: eoepca
  - name: cache-bucket
EOF
}

# Credentials - need to exist before minio install
echo -e "\nMinio credentials..."
if [ "${ACTION_HELM}" = "uninstall" ]; then
  kubectl -n "${NAMESPACE}" delete secret minio-auth
else
  kubectl create namespace "${NAMESPACE}"
  kubectl -n "${NAMESPACE}" create secret generic minio-auth \
    --from-literal=rootUser="${MINIO_ROOT_USER}" \
    --from-literal=rootPassword="${MINIO_ROOT_PASSWORD}" \
    --dry-run=client -oyaml \
    | kubectl apply -f -
fi

# Minio
echo -e "\nMinio..."
if [ "${ACTION_HELM}" = "uninstall" ]; then
  helm --namespace "${NAMESPACE}" uninstall minio
else
  values | helm ${ACTION_HELM} minio minio -f - \
    --repo https://charts.min.io/ \
    --namespace "${NAMESPACE}" --create-namespace \
    --wait
fi

# s3cfg
if [ "${ACTION}" = "apply" ]; then
  cat - <<EOF > s3cfg
[default]
  access_key = eoepca
  access_token = 
  add_encoding_exts = 
  add_headers = 
  bucket_location = us-east-1
  ca_certs_file = 
  cache_file = 
  check_ssl_certificate = True
  check_ssl_hostname = True
  cloudfront_host = cloudfront.amazonaws.com
  connection_max_age = 5
  connection_pooling = True
  content_disposition = 
  content_type = 
  default_mime_type = binary/octet-stream
  delay_updates = False
  delete_after = False
  delete_after_fetch = False
  delete_removed = False
  dry_run = False
  enable_multipart = True
  encoding = UTF-8
  encrypt = False
  expiry_date = 
  expiry_days = 
  expiry_prefix = 
  follow_symlinks = False
  force = False
  get_continue = False
  gpg_command = /usr/bin/gpg
  gpg_decrypt = %(gpg_command)s -d --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
  gpg_encrypt = %(gpg_command)s -c --verbose --no-use-agent --batch --yes --passphrase-fd %(passphrase_fd)s -o %(output_file)s %(input_file)s
  gpg_passphrase = 
  guess_mime_type = True
  host_base = minio.${domain}
  host_bucket = minio.${domain}
  human_readable_sizes = False
  invalidate_default_index_on_cf = False
  invalidate_default_index_root_on_cf = True
  invalidate_on_cf = False
  kms_key = 
  limit = -1
  limitrate = 0
  list_md5 = False
  log_target_prefix = 
  long_listing = False
  max_delete = -1
  mime_type = 
  multipart_chunk_size_mb = 15
  multipart_copy_chunk_size_mb = 1024
  multipart_max_chunks = 10000
  preserve_attrs = True
  progress_meter = True
  proxy_host = 
  proxy_port = 0
  public_url_use_https = False
  put_continue = False
  recursive = False
  recv_chunk = 65536
  reduced_redundancy = False
  requester_pays = False
  restore_days = 1
  restore_priority = Standard
  secret_key = changeme
  send_chunk = 65536
  server_side_encryption = False
  signature_v2 = False
  signurl_use_https = False
  simpledb_host = sdb.amazonaws.com
  skip_existing = False
  socket_timeout = 300
  ssl_client_cert_file = 
  ssl_client_key_file = 
  stats = False
  stop_on_error = False
  storage_class = 
  throttle_max = 100
  upload_id = 
  urlencoding_mode = normal
  use_http_expect = False
  use_https = False
  use_mime_magic = True
  verbosity = WARNING
  website_endpoint = http://%(bucket)s.s3-website-%(location)s.amazonaws.com/
  website_error = 
  website_index = index.html
EOF
elif [ "${ACTION}" = "delete" ]; then
  rm -f s3cfg
fi
