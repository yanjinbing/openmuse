#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <version>" >&2
  echo "Example: $0 1.0.0" >&2
  exit 1
fi

VERSION="$1"
IMAGE="registry.sandbox.airacloud.com/default/openmuse:${VERSION}"

echo "Building ${IMAGE}"
sudo docker build \
  --tag "${IMAGE}" \
  --file "${ROOT_DIR}/Dockerfile" \
  "${ROOT_DIR}"

echo "Built ${IMAGE}"

