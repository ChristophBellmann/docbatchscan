#!/usr/bin/env bash
# Duplex-Stapelscan für den Canon DR-C225: durchsuchbares PDF, sprechender Name.

set -euo pipefail

SELF_CHECK_ONLY=0
if [[ "${1:-}" == "--selfcheck" ]]; then
  SELF_CHECK_ONLY=1
  shift
fi

# Standard-Ablage: das Verzeichnis, in dem der Aufruf erfolgt.
DEFAULT_OUTDIR="${SCAN_OUTDIR:-$PWD}"
if [[ $# -ge 1 ]]; then
  OUTFILE="$1"
  AUTONAME_ALLOWED=0
else
  OUTFILE="${DEFAULT_OUTDIR}/scan_$(date +%Y%m%d_%H%M%S).pdf"
  AUTONAME_ALLOWED=1
fi

# Nachbearbeitung: OCR und automatische Benennung (jeweils per Env abschaltbar).
SCAN_OCR="${SCAN_OCR:-1}"
SCAN_AUTONAME="${SCAN_AUTONAME:-1}"
SCAN_NAME_MODEL="${SCAN_NAME_MODEL:-opencode-go/glm-5.3}"
SCAN_OCR_LANG="${SCAN_OCR_LANG:-deu+eng}"

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
WORKDIR=$(mktemp -d "${TMPBASE}/canondr.XXXXXX")

cleanup() {
  log "Bereinige temporäre Dateien"
  rm -rf "$WORKDIR"
  if [[ -n "${SCAN_ERR_LOG:-}" && -f "${SCAN_ERR_LOG}" ]]; then
    rm -f "${SCAN_ERR_LOG}"
  fi
}
trap cleanup EXIT

DEVICE="$(detect_device)"
log "Starte Duplex-Stapel auf ${DEVICE} in Farbe (300 dpi) → temporär: $WORKDIR"
SCAN_ERR_LOG="$(mktemp "${TMPBASE}/canondr_scanerr.XXXXXX.log")"
if [[ "${DEVICE}" == canondr:* ]]; then
  if ! self_scanimage \
    --device "${DEVICE}" \
    --ScanMode Duplex \
    --mode Color \
    --resolution 300 \
    --Size "Auto Size" \
    --format=jpeg \
    --batch="${WORKDIR}/page_%02d.jpg" \
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
    --batch="${WORKDIR}/page_%02d.jpg" \
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

jpeg_files=("$WORKDIR"/page_*.jpg)
if [ ! -e "${jpeg_files[0]}" ]; then
  log "Keine Seiten erfasst. Prüfe, ob Papier im Einzug liegt."
  exit 1
fi

log "Erzeuge PDF ${OUTFILE}"
img2pdf "${jpeg_files[@]}" -o "$OUTFILE"

# ---------------------------------------------------------------------------
# Nachbearbeitung. Ab hier darf nichts mehr den Lauf abbrechen: das PDF ist da
# und muss jeden Fehlschlag von OCR oder Benennung überleben.
# ---------------------------------------------------------------------------
set +e

OCR_TEXT_FILE="${WORKDIR}/ocr.txt"

# --- 1) Durchsuchbares PDF erzeugen, Text als Beifang -----------------------
if [[ "$SCAN_OCR" == "1" ]] && command -v ocrmypdf >/dev/null 2>&1; then
  log "OCR läuft (${SCAN_OCR_LANG})"
  if TMPDIR="${OCR_TMPDIR:-/tmp}" ocrmypdf \
      -l "$SCAN_OCR_LANG" \
      --rotate-pages \
      --deskew \
      --optimize 1 \
      --quiet \
      --sidecar "$OCR_TEXT_FILE" \
      "$OUTFILE" "${WORKDIR}/ocr.pdf" >/dev/null 2>&1 \
     && [[ -s "${WORKDIR}/ocr.pdf" ]]; then
    mv -f "${WORKDIR}/ocr.pdf" "$OUTFILE"
    log "PDF ist jetzt durchsuchbar."
  else
    log "OCR fehlgeschlagen, PDF bleibt unverändert."
  fi
fi

# --- 2) Notfalltext, falls OCR aus oder erfolglos ---------------------------
if [[ ! -s "$OCR_TEXT_FILE" ]] && command -v tesseract >/dev/null 2>&1; then
  : > "$OCR_TEXT_FILE"
  for page in "${jpeg_files[@]:0:2}"; do
    TMPDIR="$TMPBASE" tesseract "$page" - -l "${SCAN_OCR_LANG}" --psm 1 \
      >> "$OCR_TEXT_FILE" 2>/dev/null
  done
fi

# --- 3) Sprechenden Namen vom LLM holen ------------------------------------
sanitize() {
  printf '%s' "$1" \
    | tr '\n\r\t' '   ' \
    | sed -e 's#[/\\:*?"<>|]# #g' \
          -e 's/[^[:alnum:]._ -]//g' \
          -e 's/[ _-]\{1,\}/_/g' \
          -e 's/^[._-]*//' \
          -e 's/[._-]*$//' \
    | cut -c1-60
}

if [[ "$SCAN_AUTONAME" == "1" && "$AUTONAME_ALLOWED" == "1" ]] \
   && command -v opencode >/dev/null 2>&1 \
   && [[ -s "$OCR_TEXT_FILE" ]]; then

  OCR_SNIPPET="$(head -c 6000 "$OCR_TEXT_FILE")"
  ASKDIR="$(mktemp -d "${TMPBASE}/canondr_llm.XXXXXX")"

  read -r -d '' PROMPT <<EOF
Du bist Archivar einer Poststelle. Unten steht der OCR-Text eines eingescannten
Schreibens. Antworte mit GENAU EINER Zeile in diesem Format:

DATUM|ABSENDER|BETREFF

DATUM   = Datum des Schreibens als YYYY-MM-DD. Unbekannt: schreibe unbekannt
ABSENDER= absendende Firma, Behörde oder Person, hoechstens drei Woerter
BETREFF = worum es geht, hoechstens sechs Woerter, keine Aktenzeichen

Keine Erklaerung, keine Anfuehrungszeichen, kein Codeblock, keine Werkzeuge.

--- OCR-TEXT ---
${OCR_SNIPPET}
EOF

  log "Frage ${SCAN_NAME_MODEL} nach einem sprechenden Namen"
  LLM_RAW="$(timeout 120 opencode run \
      --model "$SCAN_NAME_MODEL" \
      --dir "$ASKDIR" \
      --auto \
      "$PROMPT" </dev/null 2>/dev/null)"
  rm -rf "$ASKDIR"

  LLM_LINE="$(printf '%s' "$LLM_RAW" | tr -d '\r' | grep -F '|' | tail -n1)"

  if [[ -n "$LLM_LINE" ]]; then
    # Datum nicht durch sanitize schicken - das frisst die Bindestriche.
    DOC_DATE="$(printf '%s' "$LLM_LINE" | cut -d'|' -f1 \
                | tr -cd '0-9.-' )"
    DOC_FROM="$(sanitize "$(printf '%s' "$LLM_LINE" | cut -d'|' -f2)")"
    DOC_SUBJ="$(sanitize "$(printf '%s' "$LLM_LINE" | cut -d'|' -f3)")"

    # Das Modell schreibt gern deutsch: 14.08.2026 -> 2026-08-14
    if [[ "$DOC_DATE" =~ ^([0-9]{2})[.-]([0-9]{2})[.-]([0-9]{4})$ ]]; then
      DOC_DATE="${BASH_REMATCH[3]}-${BASH_REMATCH[2]}-${BASH_REMATCH[1]}"
    fi
    if [[ ! "$DOC_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      DOC_DATE="$(date +%Y-%m-%d)"
    fi

    BASENAME="$DOC_DATE"
    [[ -n "$DOC_FROM" ]] && BASENAME="${BASENAME}_${DOC_FROM}"
    [[ -n "$DOC_SUBJ" ]] && BASENAME="${BASENAME}_${DOC_SUBJ}"

    if [[ -n "$DOC_FROM$DOC_SUBJ" ]]; then
      OUTDIR="$(dirname "$OUTFILE")"
      TARGET="${OUTDIR}/${BASENAME}.pdf"
      n=2
      while [[ -e "$TARGET" ]]; do
        TARGET="${OUTDIR}/${BASENAME}_${n}.pdf"
        n=$((n + 1))
      done
      if mv -n "$OUTFILE" "$TARGET" && [[ -e "$TARGET" ]]; then
        OUTFILE="$TARGET"
      else
        log "Umbenennen fehlgeschlagen, behalte Zeitstempelnamen."
      fi
    else
      log "Modell lieferte keinen brauchbaren Namen, behalte Zeitstempel."
    fi
  else
    log "Keine verwertbare Antwort vom Modell, behalte Zeitstempel."
  fi
fi

log "Fertig: ${OUTFILE}"
