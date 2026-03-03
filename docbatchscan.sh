#!/usr/bin/env bash
# Duplex color batch scan helper for Canon DR-C225, tuned for speed.

set -euo pipefail

SELF_CHECK_ONLY=0
if [[ "${1:-}" == "--selfcheck" ]]; then
  SELF_CHECK_ONLY=1
  shift
fi

DEFAULT_OUTDIR="${HOME}/Dokumente/scans"
if [[ $# -ge 1 ]]; then
  OUTFILE="$1"
else
  OUTFILE="${DEFAULT_OUTDIR}/scan_$(date +%Y%m%d_%H%M%S).pdf"
fi

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

mkdir -p "$(dirname "$OUTFILE")"

if [[ -d /opt/Canon/lib/sane ]]; then
  LIBDIR=/opt/Canon/lib/sane
elif [[ -d /opt/Canon/DRC225/lib/sane ]]; then
  LIBDIR=/opt/Canon/DRC225/lib/sane
else
  LIBDIR=/opt/Canon/lib/sane
fi

if [[ -d /opt/Canon/etc/sane.d ]]; then
  CONFDIR=/opt/Canon/etc/sane.d
elif [[ -d /opt/Canon/DRC225/etc/sane.d ]]; then
  CONFDIR=/opt/Canon/DRC225/etc/sane.d
else
  CONFDIR=/opt/Canon/etc/sane.d
fi

selfcheck() {
  local ok=1

  for cmd in scanimage img2pdf; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Fehler: benötigtes Kommando '$cmd' nicht gefunden." >&2
      ok=0
    fi
  done

  if [[ ! -d "$LIBDIR" ]]; then
    echo "Fehler: Canon-Bibliotheksordner fehlt: $LIBDIR" >&2
    ok=0
  fi

  if [[ -f "$LIBDIR/libsane-canondr.so.1.0.0" ]] && ldd "$LIBDIR/libsane-canondr.so.1.0.0" 2>/dev/null | grep -q "libusb-0.1.so.4 => not found"; then
    echo "Fehler: libusb-0.1.so.4 fehlt (installiere Paket 'libusb-0.1-4')." >&2
    ok=0
  fi

  if [[ ! -d "$CONFDIR" ]]; then
    echo "Fehler: Canon-Konfigurationsordner fehlt: $CONFDIR" >&2
    ok=0
  fi

  if [[ -f /etc/sane.d/dll.conf ]] && ! grep -Eq '^[[:space:]]*canondr([[:space:]]*(#.*)?)?$' /etc/sane.d/dll.conf; then
    echo "Warnung: 'canondr' fehlt vermutlich in /etc/sane.d/dll.conf" >&2
  fi

  if [[ "$ok" -eq 1 ]]; then
    log "Self-Check erfolgreich."
    return 0
  fi

  log "Self-Check fehlgeschlagen."
  return 1
}

self_scanimage() {
  env \
    LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" \
    SANE_CONFIG_DIR="$CONFDIR:/etc/sane.d" \
    scanimage "$@"
}

self_scanimage_canon_only() {
  env \
    LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" \
    SANE_CONFIG_DIR="$CONFDIR" \
    scanimage "$@"
}

detect_device() {
  if [[ -n "${SCAN_DEVICE:-}" ]]; then
    echo "${SCAN_DEVICE}"
    return 0
  fi

  local detected
  # Prefer proprietary Canon backend first.
  detected="$(self_scanimage_canon_only -L 2>/dev/null | sed -n "s/^device \`\\([^']*\\)'.*/\\1/p" | grep -E '^canondr:libusb:' | head -n1 || true)"
  if [[ -z "${detected}" ]]; then
    detected="$(self_scanimage -L 2>/dev/null | sed -n "s/^device \`\\([^']*\\)'.*/\\1/p" | grep -E '^canondr:libusb:' | head -n1 || true)"
  fi
  if [[ -z "${detected}" ]]; then
    detected="$(self_scanimage -L 2>/dev/null | sed -n "s/^device \`\\([^']*\\)'.*/\\1/p" | grep -E '^canon_dr:libusb:' | head -n1 || true)"
  fi
  if [[ -z "${detected}" ]]; then
    detected="$(self_scanimage -L 2>/dev/null | sed -n "s/^device \`\\([^']*\\)'.*/\\1/p" | head -n1 || true)"
  fi

  if [[ -z "${detected}" ]]; then
    echo "Fehler: Kein Scannergerät gefunden (scanimage -L)." >&2
    return 1
  fi

  echo "${detected}"
}

selfcheck
if [[ "$SELF_CHECK_ONLY" -eq 1 ]]; then
  exit 0
fi

TMPBASE=${TMPDIR:-/dev/shm}
if [ ! -d "$TMPBASE" ] || [ ! -w "$TMPBASE" ]; then
  TMPBASE=${TMPDIR:-/tmp}
fi
TMPDIR=$(mktemp -d "${TMPBASE}/canondr.XXXXXX")

cleanup() {
  log "Bereinige temporäre Dateien"
  rm -rf "$TMPDIR"
  if [[ -n "${SCAN_ERR_LOG:-}" && -f "${SCAN_ERR_LOG}" ]]; then
    rm -f "${SCAN_ERR_LOG}"
  fi
}
trap cleanup EXIT

DEVICE="$(detect_device)"
log "Starte Duplex-Stapel auf ${DEVICE} in Farbe (300 dpi) → temporär: $TMPDIR"
SCAN_ERR_LOG="$(mktemp "${TMPBASE}/canondr_scanerr.XXXXXX.log")"
if [[ "${DEVICE}" == canondr:* ]]; then
  if ! self_scanimage \
    --device "${DEVICE}" \
    --ScanMode Duplex \
    --mode Color \
    --resolution 300 \
    --Size "Auto Size" \
    --format=jpeg \
    --batch="${TMPDIR}/page_%02d.jpg" \
    --batch-start=1 \
    --progress 2> >(tee "${SCAN_ERR_LOG}" >&2); then
    if grep -qi "Document feeder out of documents" "${SCAN_ERR_LOG}"; then
      log "Kein Papier im Einzug (ADF leer)."
    else
      log "Scanlauf fehlgeschlagen."
    fi
    exit 1
  fi
else
  if ! self_scanimage \
    --device "${DEVICE}" \
    --source "ADF Duplex" \
    --mode Color \
    --resolution 300 \
    --format=jpeg \
    --batch="${TMPDIR}/page_%02d.jpg" \
    --batch-start=1 \
    --progress 2> >(tee "${SCAN_ERR_LOG}" >&2); then
    if grep -qi "Document feeder out of documents" "${SCAN_ERR_LOG}"; then
      log "Kein Papier im Einzug (ADF leer)."
    else
      log "Scanlauf fehlgeschlagen."
    fi
    exit 1
  fi
fi

jpeg_files=("$TMPDIR"/page_*.jpg)
if [ ! -e "${jpeg_files[0]}" ]; then
  log "Keine Seiten erfasst. Prüfe, ob Papier im Einzug liegt."
  exit 1
fi

log "Erzeuge PDF ${OUTFILE}"
img2pdf "${jpeg_files[@]}" -o "$OUTFILE"

log "Fertig: ${OUTFILE}"
