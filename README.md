# docbatchscan

Ein schnelles, skriptbasiertes **Duplex-Color-Batch-Scan-Tool** für den Canon **DR-C225** unter Linux.  
Optimiert für hohe Geschwindigkeit, nutzt `scanimage` + `img2pdf`.  
Es ist für die Verwendung mit dem (alten) proprietäre Canon-Treiber vorgesehen.  
Die Treiberdaten und Installationsccrips sind hier beinhaltet.  

## Features

- **Duplex-Scan** (beidseitig)  
- **Farbig** (Color)  
- **300 dpi**  
- **Batch-Modus** mit automatischer Dateinamensvergabe  
- Schnell dank Nutzung von `/dev/shm` (RAM-Disk), wenn verfügbar  
- Automatisches Aufräumen temporärer Dateien  
- Optionaler Dateiname als Parameter, sonst Zeitstempel  
- **Ablage im aktuellen Verzeichnis** — dort, wo der Aufruf erfolgt  
- **OCR** via `ocrmypdf`: durchsuchbares PDF, gedrehte Seiten werden aufgerichtet  
- **Sprechender Dateiname** aus dem OCR-Text, per LLM: `YYYY-MM-DD_Absender_Betreff.pdf`  
- Ausgabe: **PDF**

Ab dem fertigen PDF kann nichts mehr den Lauf abbrechen. Fällt OCR oder die
Benennung aus, bleibt der Scan unter seinem Zeitstempelnamen liegen — verloren
geht er nie. Namenskollisionen bekommen `_2`, `_3`; überschrieben wird nichts.

## Nutzung

```bash
./docbatchscan.sh                  # erzeugt scan_YYYYMMDD_HHMMSS.pdf
./docbatchscan.sh mein_scan.pdf
./docbatchscan.sh --selfcheck     # prüft Abhängigkeiten/Treiber ohne Scan
./scadn mein_scan.pdf             # Kurzalias
```

Aus dem Anwendungsmenü heraus gibt es zusätzlich **Dokument scannen**. Ein
Launcher hat kein sinnvolles Arbeitsverzeichnis, deshalb legt er über
`docbatchscan-gui` fest in `~/Dokumente/scans` ab.

## Beispielausgabe

```bash
[2026-08-23 13:37:01] Self-Check erfolgreich.
[2026-08-23 13:37:11] Starte Duplex-Stapel in Farbe (300 dpi) → temporär: /dev/shm/canondr.abcd12
[2026-08-23 13:37:24] Erzeuge PDF /home/christoph/Posteingang/scan_20260823_133701.pdf
[2026-08-23 13:37:44] OCR läuft (deu+eng)
[2026-08-23 13:37:44] PDF ist jetzt durchsuchbar.
[2026-08-23 13:37:50] Frage opencode-go/glm-5.3 nach einem sprechenden Namen
[2026-08-23 13:37:56] Fertig: …/2026-08-07_Katholisches_Kirchensteueramt_Kirchensteuerbescheid_2023.pdf
```

## Konfiguration

Alles über Umgebungsvariablen, nichts muss gesetzt werden:

| Variable | Standard | Wirkung |
|---|---|---|
| `SCAN_OUTDIR` | `$PWD` | Zielverzeichnis |
| `SCAN_OCR` | `1` | `0` überspringt `ocrmypdf` (spart ca. 4 s pro Seite) |
| `SCAN_AUTONAME` | `1` | `0` behält den Zeitstempelnamen |
| `SCAN_NAME_MODEL` | `opencode-go/glm-5.3` | Modell für die Benennung |
| `SCAN_OCR_LANG` | `deu+eng` | Tesseract-Sprachen |
| `SCAN_DEVICE` | automatisch | SANE-Gerät fest vorgeben |
| `OCR_TMPDIR` | `/tmp` | Zwischenablage von `ocrmypdf` (Platte, nicht RAM) |

Wird ein Dateiname als Parameter übergeben, ist die automatische Benennung aus —
ein ausdrücklich gewählter Name wird nicht überstimmt.

## Wie die Benennung funktioniert

Der OCR-Text der ersten Seiten geht an ein LLM, das mit genau einer Zeile
antwortet:

```
2026-08-07|Katholisches Kirchensteueramt Augsburg|Kirchensteuerbescheid 2023
```

Die drei Felder werden in der Shell geprüft und bereinigt, nicht im Prompt: das
Datum muss `YYYY-MM-DD` sein (deutsches `07.08.2026` wird umgesetzt), sonst
greift das Scandatum. Umlaute bleiben erhalten, Pfadtrenner fliegen raus, die
Länge wird gekappt.

Läuft ohne `opencode` oder ohne verwertbare Antwort einfach nicht — der Scan
behält dann den Zeitstempelnamen.

## Installation

Das install-script richtet docbatchscan (inkl. `scadn`-Alias) UND den Canon-Treiber (cndrvsane-drc225) ein.  
Die Treiberinstallation (dpkg) erfordert sudo.

```bash
sudo install/install.sh
```

## Deinstallation

Entfernt docbatchscan/scadn und – falls vorhanden – das Canon-Treiberpaket cndrvsane-drc225.  
Erfordert sudo.

```bash
sudo install/uninstall.sh
```

## Voraussetzungen

- Linux  
- Zwingend:
  - `scanimage`
  - `img2pdf`
- Optional, für OCR und Benennung:
  - `ocrmypdf` samt `tesseract-ocr-deu`
  - [opencode](https://github.com/sst/opencode) mit einem konfigurierten Modell

```bash
sudo apt install sane-utils img2pdf ocrmypdf tesseract-ocr-deu
```

Fehlt eines der optionalen Werkzeuge, wird der jeweilige Schritt übersprungen.

- SANE kompatibler Treiber für Canon DR-C225  

## Canon DR-C225 unter Linux (Pop!_OS/Ubuntu)

Nutzung des proprietären Canon-Backend-Treiber für den Dokumentenscanner **Canon DR‑C225**.
Es wird kein systemweiter Eingriffin die vorhandenen SANE‑Pakete
benötigt. Alles läuft isoliert in `/opt/Canon/DRC225/`.

Unterstützt Duplex und automatische Seitenerkennung.

- **Downloaden**

Von der [Canon-Supportseite für DR-C225/DR-C225W](https://www.canon.de/support/business/products/scanners/imageformula/dr-series/imageformula-dr-c225w.html?type=drivers&os=Linux%20(64-bit))
 das 
[(direktlink) Linux-Treiberpaket](https://files.canon-europe.com/files/soft46679/Software/d15106mux_Linux_v10_DRC225_DRC225W_64bit.zip) herunterladen.

- **Entpacken**

```bash
tar xvf cndrvsane-drc225-1.00-4.tar.gz
cd DR-C225_LinuxDriver_1.00-4-x86_64/x86_64/
```

- **Installieren**

Entweder über dpkg:

```bash
sudo dpkg -i cndrvsane-drc225_1.00-4_amd64.deb
```

oder über install.sh

```bash
sudo ./install.sh
```

## Infos Canon DR225 Treiber

Das Installationsskript legt alle Dateien unter:`/opt/Canon/DRC225/lib/sane/ → Canon Bibliotheken`und `/opt/Canon/DRC225/etc/sane.d/ → Canon Konfigs`

und installiert eine passende udev-Regel für Zugriffsrechte:`/etc/udev/rules.d/90-canondr.rules → USB-Rechte`

Zusätzlich wird in:`/etc/sane.d/dll.conf`der Canon-Backendname eingetragen damit  SANE erkennt dass ein Canon-Backend existiert.

```nginx
canondr
```


**Verwendung**

Scanaufrufe müssen folgende Variablen setzen, Beispiel:

```bash
env LD_LIBRARY_PATH=/opt/Canon/DRC225/lib/sane \
    SANE_CONFIG_DIR=/opt/Canon/DRC225/etc/sane.d:/etc/sane.d \
    scanimage --device canondr:libusb:X:Y ...
```

## Wenn der Scanner nicht gefunden wird

`open of device … failed: Invalid argument` bei wechselnden Gerätenummern heißt
fast immer, dass sich der Scanner laufend neu am USB-Bus anmeldet:

```bash
journalctl -k --since -2min | grep -c "USB disconnect"
```

Sind das mehr als eine Handvoll, hilft keine Software: anderer USB-Port direkt
am Mainboard, anderes Kabel, Netzteil prüfen.
