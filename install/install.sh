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
ZIP_PKG="${PROJECT_ROOT}/third_party/d15106mux_Linux_v10_DRC225_DRC225W_64bit.zip"

manual_install_from_deb() {
  local deb_file="$1"
  local tmp
  tmp="$(mktemp -d)"

  echo "Fallback: Installiere Treiber manuell aus DEB-Inhalt …"
  dpkg-deb -x "${deb_file}" "${tmp}/root"
  dpkg-deb -e "${deb_file}" "${tmp}/ctrl"
  cp -a "${tmp}/root/." /

  if [[ -x "${tmp}/ctrl/postinst" ]]; then
    sh "${tmp}/ctrl/postinst" configure
  fi

  rm -rf "${tmp}"
}

echo "Installiere docbatchscan …"

# 1) Canon-Treiber installieren (falls noch nicht vorhanden)
if command -v dpkg >/dev/null 2>&1; then
  PKG_STATUS="$(dpkg-query -W -f='${Status}' cndrvsane-drc225 2>/dev/null || true)"

  # Broken/half-installed package states block apt installs.
  if [[ -n "${PKG_STATUS}" && "${PKG_STATUS}" != "install ok installed" ]]; then
    echo "Bereinige inkonsistenten Paketstatus von cndrvsane-drc225 (${PKG_STATUS}) …"
    dpkg --remove --force-remove-reinstreq cndrvsane-drc225 >/dev/null 2>&1 || true
  fi

  if ! dpkg-query -W -f='${Status}' libusb-0.1-4 2>/dev/null | grep -q '^install ok installed$'; then
    echo "Installiere benötigte Legacy-Abhängigkeit libusb-0.1-4 …"
    apt-get update -y
    apt-get install -y libusb-0.1-4 || echo "WARNUNG: Installation von libusb-0.1-4 fehlgeschlagen." >&2
  fi

  PKG_STATUS="$(dpkg-query -W -f='${Status}' cndrvsane-drc225 2>/dev/null || true)"
  if [[ "${PKG_STATUS}" == "install ok installed" ]]; then
    echo "Canon-Treiberpaket 'cndrvsane-drc225' ist bereits installiert."
  else
    if [[ ! -f "${DEB_PKG}" ]]; then
      FOUND_DEB="$(find "${PROJECT_ROOT}/third_party" -type f -name 'cndrvsane-drc225_*_amd64.deb' | head -n1 || true)"
      if [[ -n "${FOUND_DEB}" ]]; then
        echo "Nutze gefundenes Treiber-DEB: ${FOUND_DEB}"
        DEB_PKG="${FOUND_DEB}"
      elif [[ -f "${ZIP_PKG}" ]]; then
        if command -v unzip >/dev/null 2>&1; then
          echo "Treiber-DEB fehlt, extrahiere es aus: ${ZIP_PKG}"
          mkdir -p "$(dirname "${DEB_PKG}")"
          DEB_IN_ZIP="$(unzip -Z1 "${ZIP_PKG}" | grep -E 'cndrvsane-drc225_[0-9.]+-[0-9]+_amd64\.deb$' | head -n1 || true)"
          if [[ -n "${DEB_IN_ZIP}" ]]; then
            unzip -o -j "${ZIP_PKG}" "${DEB_IN_ZIP}" -d "$(dirname "${DEB_PKG}")" >/dev/null
          else
            echo "WARNUNG: Kein passendes Treiber-DEB im ZIP gefunden." >&2
          fi
        else
          echo "WARNUNG: 'unzip' nicht installiert, kann Treiber-DEB nicht aus ZIP extrahieren." >&2
        fi
      fi
    fi

    if [[ -f "${DEB_PKG}" ]]; then
      if [[ "${DOCBATCHSCAN_FORCE_DPKG:-0}" == "1" ]]; then
        echo "Installiere Canon-Treiber aus: ${DEB_PKG}"
        if ! dpkg -i "${DEB_PKG}"; then
          echo "dpkg meldet Abhängigkeitsprobleme. Versuche manuellen Fallback …"
          dpkg --remove --force-remove-reinstreq cndrvsane-drc225 >/dev/null 2>&1 || true
          manual_install_from_deb "${DEB_PKG}"
        fi
      else
        echo "Nutze direkten Treiber-Fallback (robust auf modernen Ubuntu/Pop!_OS-Systemen)."
        manual_install_from_deb "${DEB_PKG}"
      fi
    else
      echo "WARNUNG: Treiber-DEB nicht gefunden: ${DEB_PKG}" >&2
      echo "         Der Scanner-Treiber wird NICHT automatisch installiert." >&2
    fi
  fi
else
  echo "WARNUNG: 'dpkg' nicht gefunden – Debian/Ubuntu-basiertes System erwartet." >&2
fi

# 2) docbatchscan-Script + Kurzalias installieren
install -Dm755 "${PROJECT_ROOT}/docbatchscan.sh" "/usr/local/bin/docbatchscan"
install -Dm755 "${PROJECT_ROOT}/scadn" "/usr/local/bin/scadn"

echo "Fertig. Benutze 'docbatchscan' oder 'scadn' zum Scannen."
