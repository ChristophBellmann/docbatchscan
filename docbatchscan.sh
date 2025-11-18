#!/usr/bin/env bash
# Duplex color batch scan helper for Canon DR-C225, tuned for speed.

set -euo pipefail

OUTFILE=${1:-"scan_$(date +%Y%m%d_%H%M%S).pdf"}

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$*"
}

TMPBASE=${TMPDIR:-/dev/shm}
if [ ! -d "$TMPBASE" ] || [ ! -w "$TMPBASE" ]; then
  TMPBASE=${TMPDIR:-/tmp}
fi
TMPDIR=$(mktemp -d "${TMPBASE}/canondr.XXXXXX")

cleanup() {
  log "Bereinige temporäre Dateien"
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

for cmd in scanimage img2pdf; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Fehler: benötigtes Kommando '$cmd' nicht gefunden." >&2
    exit 1
  fi
done

LIBDIR=/opt/Canon/DRC225/lib/sane
CONFDIR=/opt/Canon/DRC225/etc/sane.d

log "Starte Duplex-Stapel in Farbe (300 dpi) → temporär: $TMPDIR"
env \
  LD_LIBRARY_PATH="$LIBDIR:${LD_LIBRARY_PATH:-}" \
  SANE_CONFIG_DIR="$CONFDIR:/etc/sane.d" \
  scanimage \
    --device canondr:libusb:003:005 \
    --ScanMode Duplex \
    --mode Color \
    --resolution 300 \
    --Size "Auto Size" \
    --format=jpeg \
    --batch="${TMPDIR}/page_%02d.jpg" \
    --batch-start=1 \
    --progress

jpeg_files=("$TMPDIR"/page_*.jpg)
if [ ! -e "${jpeg_files[0]}" ]; then
  log "Keine Seiten erfasst – Abbruch."
  exit 1
fi

log "Erzeuge PDF ${OUTFILE}"
img2pdf "${jpeg_files[@]}" -o "$OUTFILE"

log "Fertig: ${OUTFILE}"
