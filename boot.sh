#!/bin/sh
set -eu

APP_DIR="/data/xiaoai-airplay1"
AIRPLAY_BIN="${APP_DIR}/shairport-sync"
AIRPLAY_CFG="${APP_DIR}/shairport-sync.conf"
AIRPLAY_LOG="${APP_DIR}/shairport.log"
AIRPLAY_HOOK="${APP_DIR}/airplay-hook.sh"
AIRPLAY_VOL_HOOK="${APP_DIR}/volume-hook.sh"
AIRPLAY_ALSA_DEV="notify"
WAIT_HOST="223.5.5.5"
WAIT_SECONDS=60

if [ ! -x "${AIRPLAY_BIN}" ]; then
  echo "Error: executable not found at ${AIRPLAY_BIN}" >&2
  exit 1
fi

if [ ! -f "${AIRPLAY_CFG}" ]; then
  echo "Error: config not found at ${AIRPLAY_CFG}" >&2
  exit 1
fi

if command -v ping >/dev/null 2>&1; then
  i=0
  while [ "${i}" -lt "${WAIT_SECONDS}" ]; do
    if ping -c 1 "${WAIT_HOST}" >/dev/null 2>&1; then
      break
    fi
    i=$((i + 1))
    sleep 1
  done
fi

PIDS_OLD="$(ps | grep '[x]iaoai_plus_speaker' | awk '{print $1}' || true)"
if [ -n "${PIDS_OLD}" ]; then
  kill -CONT ${PIDS_OLD} >/dev/null 2>&1 || true
  kill -9 ${PIDS_OLD} >/dev/null 2>&1 || true
fi

PIDS_AP="$(ps | grep '[s]hairport-sync' | awk '{print $1}' || true)"
if [ -n "${PIDS_AP}" ]; then
  kill -CONT ${PIDS_AP} >/dev/null 2>&1 || true
  kill ${PIDS_AP} >/dev/null 2>&1 || true
fi

PIDS_MI="$(pidof mipns-xiaomi 2>/dev/null || true)"
if [ -n "${PIDS_MI}" ]; then
  kill -CONT ${PIDS_MI} >/dev/null 2>&1 || true
fi
rm -f /tmp/airplay_pre_vol /tmp/airplay_last_vol
sleep 1

cd "${APP_DIR}"

cat > "${AIRPLAY_VOL_HOOK}" <<'VOLHOOK'
#!/bin/sh
SAVED_FILE="/tmp/airplay_pre_vol"
if [ ! -f "${SAVED_FILE}" ]; then
  PRE_VOL="$(amixer sget mysoftvol | awk -F' ' '/Front Left:/ {print $3}' | head -n 1)"
  case "${PRE_VOL}" in
    ''|*[!0-9]*) PRE_VOL=180 ;;
  esac
  echo "${PRE_VOL}" > "${SAVED_FILE}"
fi

DB="${1:--30}"
VOL255="$(awk -v db="${DB}" 'BEGIN {
  if (db <= -30.0) { print 0; exit }
  if (db >= 0.0) { print 255; exit }
  printf "%d\n", int(((db + 30.0) / 30.0) * 255.0 + 0.5)
}')"
amixer sset mysoftvol "${VOL255}" >/dev/null 2>&1 || true
amixer sset notifyvol 255 >/dev/null 2>&1 || true
exit 0
VOLHOOK
chmod +x "${AIRPLAY_VOL_HOOK}"

cat > "${AIRPLAY_HOOK}" <<'HOOK'
#!/bin/sh
PIDS="$(pidof mipns-xiaomi 2>/dev/null || true)"
SAVED_FILE="/tmp/airplay_pre_vol"

case "${1:-}" in
  start)
    mphelper pause >/dev/null 2>&1 || true
    killall miplayer >/dev/null 2>&1 || true
    [ -n "${PIDS}" ] && kill -STOP ${PIDS}

    if [ ! -f "${SAVED_FILE}" ]; then
      PRE_VOL="$(amixer sget mysoftvol | awk -F' ' '/Front Left:/ {print $3}' | head -n 1)"
      case "${PRE_VOL}" in
        ''|*[!0-9]*) PRE_VOL=180 ;;
      esac
      echo "${PRE_VOL}" > "${SAVED_FILE}"
    fi
    amixer sset notifyvol 255 >/dev/null 2>&1 || true
    ;;

  stop)
    if [ -f "${SAVED_FILE}" ]; then
      RESTORE_VOL="$(cat "${SAVED_FILE}")"
      rm -f "${SAVED_FILE}"
    else
      RESTORE_VOL=180
    fi
    case "${RESTORE_VOL}" in
      ''|*[!0-9]*) RESTORE_VOL=180 ;;
    esac

    amixer sset mysoftvol "${RESTORE_VOL}" >/dev/null 2>&1 || true
    amixer sset notifyvol "${RESTORE_VOL}" >/dev/null 2>&1 || true

    [ -n "${PIDS}" ] && kill -CONT ${PIDS}
    ;;
esac
exit 0
HOOK
chmod +x "${AIRPLAY_HOOK}"

echo "Starting high fidelity AirPlay 1 service..."
(
  nice -n -10 "${AIRPLAY_BIN}" -c "${AIRPLAY_CFG}" 2>"${AIRPLAY_LOG}" |
    nice -n -10 aplay -q -D "${AIRPLAY_ALSA_DEV}" -t raw -f S16_LE -r 44100 -c 2 \
      --buffer-size=4096 --period-size=1024
) &

sleep 1
if ! ps | grep -q '[s]hairport-sync'; then
  echo "Warning: AirPlay failed to start, check ${AIRPLAY_LOG}" >&2
  exit 1
fi

echo "AirPlay 1 started. Log: ${AIRPLAY_LOG}"
