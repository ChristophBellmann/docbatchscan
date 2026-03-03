#!/usr/bin/env bash
set -euo pipefail

# Entfernt docbatchscan und – falls vorhanden – das Canon-Treiberpaket cndrvsane-drc225.
# Bitte mit sudo ausführen.

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Bitte mit sudo ausführen: sudo $0" >&2
  exit 1
fi

echo "Entferne docbatchscan …"
rm -f /usr/local/bin/docbatchscan || true
rm -f /usr/local/bin/scadn || true

# Canon-Treiber entfernen (optional)
if command -v dpkg >/dev/null 2>&1; then
  if dpkg -s cndrvsane-drc225 >/dev/null 2>&1; then
    echo "Entferne Canon-Treiberpaket 'cndrvsane-drc225' …"
    apt-get remove -y cndrvsane-drc225
  else
    echo "Canon-Treiberpaket 'cndrvsane-drc225' ist nicht installiert (übersprungen)."
  fi
else
  echo "Hinweis: 'dpkg' nicht gefunden – kann Canon-Treiber nicht automatisch entfernen."
fi

echo "Deinstallation abgeschlossen."
