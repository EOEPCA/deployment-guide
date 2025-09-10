#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

export PUSER="$(id -un)"
export PUID="$(id -u)"
export PGID="$(id -g)"

export EXPOSE_PORT="${1:-8888}"

COMPOSE_FILE="jupyterlab/docker-compose.yml"

function onExit() {
  if [ -n "${DOCKER_COMPOSE_CMD}" ]; then
    ${DOCKER_COMPOSE_CMD} -f "${COMPOSE_FILE}" down
  fi
  cd "${ORIG_DIR}"
}
trap "onExit" EXIT

# Check for docker support
if ! command -v docker &>/dev/null; then
  echo "ERROR - docker is required" 1>&2
  exit 1
fi
# Check for docker compose support
if command -v docker-compose &>/dev/null; then
  DOCKER_COMPOSE_CMD="docker-compose"
fi
if docker compose version &>/dev/null; then
  DOCKER_COMPOSE_CMD="docker compose"
fi
if [ -z "${DOCKER_COMPOSE_CMD}" ]; then
  echo "ERROR - docker-compose or docker compose is required" 1>&2
  exit 1
fi

xdg-open "http://localhost:${EXPOSE_PORT}"
${DOCKER_COMPOSE_CMD} -f "${COMPOSE_FILE}" up --build
