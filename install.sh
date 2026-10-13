#!/bin/sh
set -eu

APP_DIR="${APP_DIR:-/data/xiaoai-airplay1}"
JSDELIVR_ARCHIVE_URL="${JSDELIVR_ARCHIVE_URL:-https://fastly.jsdelivr.net/gh/dexterchock/xiaoai-airplay1@cdn/oh2p.tar.gz}"
ARCHIVE_URL="${ARCHIVE_URL:-${JSDELIVR_ARCHIVE_URL}}"
ARCHIVE_FALLBACK_URL="${ARCHIVE_FALLBACK_URL:-https://github.com/dexterchock/xiaoai-airplay1/releases/latest/download/oh2p.tar.gz}"
MIN_SPACE_MB="${MIN_SPACE_MB:-15}"

# Clean up legacy xiaoai-plus / xiaoai-gemini installation if present
PIDS_OLD="$(ps | grep '[x]iaoai_plus_speaker' | awk '{print $1}' || true)"
if [ -n "${PIDS_OLD}" ]; then
  kill -CONT ${PIDS_OLD} >/dev/null 2>&1 || true
  kill -9 ${PIDS_OLD} >/dev/null 2>&1 || true
fi
rm -rf /data/xiaoai-plus

CHECK_DIR="${APP_DIR}"
while [ ! -d "${CHECK_DIR}" ]; do
  if [ "${CHECK_DIR}" = "/" ]; then
    break
  fi
  CHECK_DIR="$(dirname "${CHECK_DIR}")"
done

avail_kb="$(df -k "${CHECK_DIR}" 2>/dev/null | awk 'NR==2 {print $4}')"
need_kb=$((MIN_SPACE_MB * 1024))
if [ -z "${avail_kb}" ] || [ "${avail_kb}" -lt "${need_kb}" ]; then
  echo "Error: insufficient disk space in ${CHECK_DIR} (need ${MIN_SPACE_MB}MB)" >&2
  exit 1
fi

TMP_DIR="${APP_DIR}/.install-tmp.$$"
ARCHIVE_PATH="${TMP_DIR}/oh2p.tar.gz"
SRC_DIR="${TMP_DIR}/oh2p"
trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM

mkdir -p "${TMP_DIR}" "${APP_DIR}"

echo "Downloading xiaoai-airplay1 package..."
if ! curl -fL --progress-bar "${ARCHIVE_URL}" -o "${ARCHIVE_PATH}"; then
  echo "Mirror failed, falling back to GitHub Release..." >&2
  rm -f "${ARCHIVE_PATH}"
  curl -fL --progress-bar "${ARCHIVE_FALLBACK_URL}" -o "${ARCHIVE_PATH}"
fi

tar -xzf "${ARCHIVE_PATH}" -C "${TMP_DIR}"

cp "${SRC_DIR}/shairport-sync" "${APP_DIR}/shairport-sync"
chmod 0755 "${APP_DIR}/shairport-sync"

if [ ! -f "${APP_DIR}/shairport-sync.conf" ]; then
  cp "${SRC_DIR}/shairport-sync.conf" "${APP_DIR}/shairport-sync.conf"
  chmod 0644 "${APP_DIR}/shairport-sync.conf"
fi

echo "Installation complete: ${APP_DIR}"
