#!/usr/bin/env bash
set -euo pipefail

# Dieses Script richtet docbatchscan UND den Canon-Treiber (cndrvsane-drc225) ein.
# Bitte mit sudo ausführen.

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Bitte mit sudo ausführen: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEB_PKG="${PROJECT_ROOT}/third_party/canon_dr225/cndrvsane-drc225_1.00-4_amd64.deb"

echo "Installiere docbatchscan …"

# 1) Canon-Treiber installieren (falls noch nicht vorhanden)
if command -v dpkg >/dev/null 2>&1; then
  if dpkg -s cndrvsane-drc225 >/dev/null 2>&1; then
    echo "Canon-Treiberpaket 'cndrvsane-drc225' ist bereits installiert."
  else
    if [[ -f "${DEB_PKG}" ]]; then
      echo "Installiere Canon-Treiber aus: ${DEB_PKG}"
      if ! dpkg -i "${DEB_PKG}"; then
        echo "dpkg meldet fehlende Abhängigkeiten – führe 'apt-get -f install' aus …"
        apt-get -f install -y
      fi
    else
      echo "WARNUNG: Treiber-DEB nicht gefunden: ${DEB_PKG}" >&2
      echo "         Der Scanner-Treiber wird NICHT automatisch installiert." >&2
    fi
  fi
else
  echo "WARNUNG: 'dpkg' nicht gefunden – Debian/Ubuntu-basiertes System erwartet." >&2
fi

# 2) docbatchscan-Script installieren
install -Dm755 "${PROJECT_ROOT}/docbatchscan.sh" "/usr/local/bin/docbatchscan"

echo "Fertig. Benutze 'docbatchscan' zum Scannen."

