#!/usr/bin/env bash
# Baut Creative Craft als installierbare RPM-Datei (Fedora, openSUSE, RHEL & Co.).
#
# Voraussetzungen:
#   Fedora:   sudo dnf install rpm-build godot
#   openSUSE: sudo zypper install rpm-build godot
#   (Godot geht auch als Flatpak: flatpak install flathub org.godotengine.Godot)
#
# Benutzung:  ./rpm/build-rpm.sh
# Ergebnis:   build/creative-craft-<version>.x86_64.rpm
set -euo pipefail

VERSION="0.3.0"
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

if ! command -v rpmbuild >/dev/null 2>&1; then
  echo "rpmbuild fehlt. Installieren mit:"
  echo "  Fedora:   sudo dnf install rpm-build"
  echo "  openSUSE: sudo zypper install rpm-build"
  exit 1
fi

# --- Godot finden ---
NATIVE_GODOT=""
if [ -n "${GODOT:-}" ]; then
  NATIVE_GODOT="$(command -v "$GODOT" || true)"
elif command -v godot >/dev/null 2>&1; then
  GODOT="godot"; NATIVE_GODOT="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT="godot4"; NATIVE_GODOT="$(command -v godot4)"
elif flatpak info org.godotengine.Godot >/dev/null 2>&1; then
  GODOT="flatpak run --filesystem=$ROOT org.godotengine.Godot"
else
  echo "Godot nicht gefunden. Installiere es z.B. mit: sudo dnf install godot"
  exit 1
fi
echo ">> Godot: $GODOT"

mkdir -p build/linux
$GODOT --headless --path . --import >/dev/null 2>&1 || true

# --- Export ---
# Variante 1: mit Godot-Exportvorlagen -> eigenständige Spiel-Binärdatei
BIN=""
if $GODOT --headless --path . --export-release "Linux" build/linux/CreativeCraft.x86_64 \
   && [ -f build/linux/CreativeCraft.x86_64 ] && [ -f build/linux/CreativeCraft.pck ]; then
  BIN="build/linux/CreativeCraft.x86_64"
  echo ">> Export mit Exportvorlagen erfolgreich"
else
  # Variante 2: ohne Vorlagen -> nur Spieldaten (.pck) exportieren und
  # das installierte Godot als Laufzeit mit ins Paket legen
  echo ">> Keine Exportvorlagen gefunden – verwende Godot selbst als Laufzeit"
  $GODOT --headless --path . --export-pack "Linux" build/linux/CreativeCraft.pck
  if [ -z "$NATIVE_GODOT" ]; then
    echo "Mit Flatpak-Godot werden die Exportvorlagen benötigt:"
    echo "  Godot öffnen -> Editor -> Exportvorlagen verwalten -> Herunterladen und installieren"
    exit 1
  fi
  BIN="$(readlink -f "$NATIVE_GODOT")"
  if head -c 2 "$BIN" | grep -q '#!'; then
    echo "Fehler: $BIN ist ein Startskript und keine Godot-Binärdatei."
    echo "Gib die echte Datei an: GODOT=/pfad/zu/Godot_v4.x_linux.x86_64 ./rpm/build-rpm.sh"
    exit 1
  fi
fi
[ -f build/linux/CreativeCraft.pck ] || { echo "Export fehlgeschlagen."; exit 1; }

# --- RPM bauen ---
TOP="$ROOT/build/rpmbuild"
rm -rf "$TOP"
mkdir -p "$TOP"/{SOURCES,SPECS,BUILD,RPMS,SRPMS}
cp "$BIN"                                   "$TOP/SOURCES/creative-craft-bin"
cp build/linux/CreativeCraft.pck                "$TOP/SOURCES/CreativeCraft.pck"
cp rpm/creative-craft.sh                         "$TOP/SOURCES/creative-craft.sh"
cp flatpak/org.creativecraft.CreativeCraft.desktop  "$TOP/SOURCES/"
cp flatpak/org.creativecraft.CreativeCraft.metainfo.xml "$TOP/SOURCES/"
tar -cf "$TOP/SOURCES/icons.tar" -C icons .
cp rpm/creative-craft.spec                       "$TOP/SPECS/"

rpmbuild --define "_topdir $TOP" --define "pkgversion $VERSION" -bb "$TOP/SPECS/creative-craft.spec"

RPM_FILE="$(find "$TOP/RPMS" -name 'creative-craft-*.rpm' | head -n 1)"
cp "$RPM_FILE" build/
echo
echo ">> Fertig: build/$(basename "$RPM_FILE")"
echo "   Installieren:  sudo dnf install ./build/$(basename "$RPM_FILE")"
echo "                  (openSUSE: sudo zypper install ./build/$(basename "$RPM_FILE"))"
echo "   Starten:       creative-craft   (oder über das Anwendungsmenü)"
echo "   Entfernen:     sudo dnf remove creative-craft"
