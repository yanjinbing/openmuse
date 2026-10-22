#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
IMAGE="${OPENMUSE_IMAGE:-openmuse-app:local}"
CONTAINER="${OPENMUSE_CONTAINER:-openmuse}"
ENV_FILE="${OPENMUSE_ENV_FILE:-${ROOT_DIR}/.env.e2b}"
PORT="${OPENMUSE_PORT:-8787}"

# This deployment intentionally has no host volume. Replacing the container also
# removes its local database, files and signing key.
sudo docker rm --force "${CONTAINER}" >/dev/null 2>&1 || true

sudo docker run --detach \
  --name "${CONTAINER}" \
  --restart unless-stopped \
  --env-file "${ENV_FILE}" \
  --env HOST=127.0.0.1 \
  --env PORT=8788 \
  --publish "${PORT}:8787" \
  "${IMAGE}"

echo "OpenMuse is running at http://localhost:${PORT}"
echo "Logs: docker logs -f ${CONTAINER}"

sudo docker logs -f openmuse