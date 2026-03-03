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
  PKG_STATUS="$(dpkg-query -W -f='${Status}' cndrvsane-drc225 2>/dev/null || true)"
  if [[ "${PKG_STATUS}" == "install ok installed" ]]; then
    echo "Entferne Canon-Treiberpaket 'cndrvsane-drc225' …"
    apt-get remove -y cndrvsane-drc225
  elif [[ "${PKG_STATUS}" == "deinstall ok config-files" ]]; then
    echo "Bereinige verbliebene Paket-Konfiguration von 'cndrvsane-drc225' …"
    dpkg --purge cndrvsane-drc225 >/dev/null 2>&1 || true
  else
    echo "Canon-Treiberpaket 'cndrvsane-drc225' ist nicht installiert (übersprungen)."
  fi
else
  echo "Hinweis: 'dpkg' nicht gefunden – kann Canon-Treiber nicht automatisch entfernen."
fi

# Dateien aus manuellem Treiber-Fallback entfernen.
rm -f /etc/udev/rules.d/80-cndrvsane.rules || true
rm -f /usr/lib/x86_64-linux-gnu/sane/libsane-canondr.so || true
rm -f /usr/lib/x86_64-linux-gnu/sane/libsane-canondr.so.1 || true
rm -f /usr/lib/x86_64-linux-gnu/sane/libsane-canondr.so.1.0.0 || true
rm -f /usr/lib/sane/libsane-canondr.so || true
rm -f /usr/lib/sane/libsane-canondr.so.1 || true
rm -f /usr/lib/sane/libsane-canondr.so.1.0.0 || true
rm -rf /opt/Canon || true

# canondr-Eintrag aus dll.conf entfernen, falls vorhanden.
if [[ -f /etc/sane.d/dll.conf ]]; then
  sed -i '/^[[:space:]]*canondr[[:space:]]*$/d' /etc/sane.d/dll.conf
fi

echo "Deinstallation abgeschlossen."
