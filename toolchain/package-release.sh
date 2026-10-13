#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUTPUT_DIR="${PROJECT_ROOT}/dist/release"
PACKAGE_DIR="${OUTPUT_DIR}/oh2p"
ARCHIVE_NAME="oh2p.tar.gz"
ARCHIVE_PATH="${OUTPUT_DIR}/${ARCHIVE_NAME}"

AIRPLAY_BIN="${PROJECT_ROOT}/build/shairport-sync"
AIRPLAY_CONF="${PROJECT_ROOT}/shairport-sync.conf"

require_file() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "missing required file: $f" >&2
    exit 1
  fi
}

require_file "${AIRPLAY_BIN}"
require_file "${AIRPLAY_CONF}"

rm -rf "${PACKAGE_DIR}"
mkdir -p "${PACKAGE_DIR}"

install -m 0755 "${AIRPLAY_BIN}" "${PACKAGE_DIR}/shairport-sync"
install -m 0644 "${AIRPLAY_CONF}" "${PACKAGE_DIR}/shairport-sync.conf"

mkdir -p "${OUTPUT_DIR}"
tar -C "${OUTPUT_DIR}" -czf "${ARCHIVE_PATH}" "oh2p"
(cd "${OUTPUT_DIR}" && sha256sum "${ARCHIVE_NAME}" > "${ARCHIVE_NAME}.sha256")

echo "release archive: ${ARCHIVE_PATH}"
echo "checksum file: ${ARCHIVE_PATH}.sha256"
