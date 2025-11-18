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
- Ausgabe: **PDF**

## Nutzung

```bash
./docbatchscan.sh                  # erzeugt scan_YYYYMMDD_HHMMSS.pdf
./docbatchscan.sh mein_scan.pdf
```

## Beispielausgabe

```bash
[2025-01-01 12:00:00] Starte Duplex-Stapel in Farbe (300 dpi) → temporär: /dev/shm/canondr.abcd12
[2025-01-01 12:00:15] Erzeuge PDF mein_scan.pdf
[2025-01-01 12:00:15] Fertig: mein_scan.pdf
```

## Installation

Das install-script richtet docbatchscan UND den Canon-Treiber (cndrvsane-drc225) ein.  
Die Treiberinstallation (dpkg) erfordert sudo.

```bash
sudo install/install.sh
```

## Deinstallation

Entfernt docbatchscan und – falls vorhanden – das Canon-Treiberpaket cndrvsane-drc225.  
Erfordert sudo.

```bash
sudo install/uninstall.sh
```

## Voraussetzungen

- Linux  
- Installierte Tools:
  - `scanimage`
  - `img2pdf`

```bash
sudo apt install sane-utils img2pdf
```
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



