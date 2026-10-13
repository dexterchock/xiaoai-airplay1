#!/bin/sh
set -eu

APP_DIR="/data/xiaoai-airplay1"
AIRPLAY_BIN="${APP_DIR}/shairport-sync"
AIRPLAY_CFG="${APP_DIR}/shairport-sync.conf"
AIRPLAY_LOG="${APP_DIR}/shairport.log"
AIRPLAY_HOOK="${APP_DIR}/airplay-hook.sh"
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

# Stop any legacy AI speaker or old shairport-sync processes
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
sleep 1

# Set ALSA notify softvol to 100% unity gain so all attenuation happens
# inside shairport-sync's 32-bit TPDF-dithered mixer
if command -v amixer >/dev/null 2>&1; then
  amixer sset notify 100% >/dev/null 2>&1 || amixer sset 'notify' 255 >/dev/null 2>&1 || true
fi

cd "${APP_DIR}"

# Freeze XiaoAi wake word daemon while AirPlay is streaming to dedicate CPU to SoXR
cat > "${AIRPLAY_HOOK}" <<'HOOK'
#!/bin/sh
PIDS="$(pidof mipns-xiaomi 2>/dev/null || true)"
case "${1:-}" in
  start)
    mphelper pause >/dev/null 2>&1 || true
    killall miplayer >/dev/null 2>&1 || true
    [ -n "${PIDS}" ] && kill -STOP ${PIDS}
    ;;
  stop)
    [ -n "${PIDS}" ] && kill -CONT ${PIDS}
    ;;
esac
exit 0
HOOK
chmod +x "${AIRPLAY_HOOK}"

echo "Starting high-fidelity AirPlay 1 service..."
(
  nice -n -10 "${AIRPLAY_BIN}" -c "${AIRPLAY_CFG}" 2>"${AIRPLAY_LOG}" |
    nice -n -10 aplay -q -D "${AIRPLAY_ALSA_DEV}" -t raw -f S16_LE -r 44100 -c 2 \
      --buffer-size=16384 --period-size=2048
) &

sleep 1
if ! ps | grep -q '[s]hairport-sync'; then
  echo "Warning: AirPlay failed to start, check ${AIRPLAY_LOG}" >&2
  exit 1
fi

echo "AirPlay 1 started. Log: ${AIRPLAY_LOG}"
