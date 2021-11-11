#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}
trap onExit EXIT

ACTION="${@:-apply}"

values() {
  cat - <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: proc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: eoepca-proc-pvc
  namespace: proc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: standard
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Namespace
metadata:
  name: rm
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: eoepca-resman-pvc
  namespace: rm
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: standard
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: eoepca-userman-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: standard
  resources:
    requests:
      storage: 5Gi
EOF
}

values | kubectl ${ACTION} -f -
