#!/usr/bin/env bash
# Baut Creative Craft als Flatpak und installiert es für den aktuellen Benutzer.
#
# Voraussetzungen:
#   - Godot 4.3+ (normal installiert ODER als Flatpak org.godotengine.Godot)
#   - Godot-Exportvorlagen (Editor: Editor > Exportvorlagen verwalten > Herunterladen)
#   - flatpak und flatpak-builder (z.B. sudo apt install flatpak flatpak-builder)
#
# Benutzung:   ./flatpak/build-flatpak.sh
# Eigenes Godot: GODOT=/pfad/zu/godot ./flatpak/build-flatpak.sh
set -euo pipefail

APP_ID="org.creativecraft.CreativeCraft"
RUNTIME_VERSION="25.08"
cd "$(dirname "$0")/.."

# 1) Godot finden
if [ -z "${GODOT:-}" ]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT="godot"
  elif command -v godot4 >/dev/null 2>&1; then
    GODOT="godot4"
  elif flatpak info org.godotengine.Godot >/dev/null 2>&1; then
    GODOT="flatpak run --filesystem=$(pwd) org.godotengine.Godot"
  else
    echo "Godot wurde nicht gefunden. Installiere es z.B. mit:"
    echo "  flatpak install flathub org.godotengine.Godot"
    exit 1
  fi
fi
echo ">> Verwende Godot: $GODOT"

# 2) Linux-Version exportieren
mkdir -p build/linux
$GODOT --headless --path . --import || true
$GODOT --headless --path . --export-release "Linux" build/linux/CreativeCraft.x86_64
if [ ! -f build/linux/CreativeCraft.pck ]; then
  echo "Export fehlgeschlagen – sind die Godot-Exportvorlagen installiert?"
  exit 1
fi

# 3) Laufzeitumgebung besorgen
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub "org.freedesktop.Platform//${RUNTIME_VERSION}" "org.freedesktop.Sdk//${RUNTIME_VERSION}"

# 4) Flatpak bauen, installieren und zusätzlich als Datei bündeln
flatpak-builder --user --install --force-clean --repo=flatpak/repo flatpak/build-dir "flatpak/${APP_ID}.yml"
flatpak build-bundle flatpak/repo "build/CreativeCraft.flatpak" "$APP_ID"

echo
echo ">> Fertig!"
echo "   Starten:              flatpak run $APP_ID"
echo "   Bundle zum Weitergeben: build/CreativeCraft.flatpak"
echo "   (installieren mit:    flatpak install --user build/CreativeCraft.flatpak)"
