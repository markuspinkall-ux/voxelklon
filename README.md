# VoxelKlon – ein Minecraft-Klon in Godot 4

Komplett in GDScript, ohne externe Assets: alle Texturen und Icons werden beim Start prozedural erzeugt.

## Features

- **Unendliche Voxel-Welt** in Chunks (16×80×16), zufälliger Seed bei jedem Start
- **Gebirge** mit Felswänden und Schneegipfeln, Ebenen, Strände, **Seen & Meere**, Höhlen mit Erzen (Kohle, Eisen, Diamant)
- **Bäume aus Voxeln** (Eichenstamm + Laub, Wälder und einzelne Bäume), Blumen und Gras
- **Villager-Dörfer**: Häuser mit Glasfenstern, Tür, Werkbank, Fackel und Beute-Truhe, Brunnen mit Wasser, Trampelpfade – und **Villager**, die herumlaufen (und fliehen, wenn man sie haut). Man startet direkt neben einem Dorf.
- **Wasser**: durchsichtig, Schwimmen, Ertrinken (Luftblasen-Anzeige), Unterwasser-Nebel, Eimer & Wassereimer, Löcher neben Wasser laufen voll
- **Lebensanzeige** mit 10 Herzen, Fallschaden, Regeneration, Essen (Äpfel, verrottetes Fleisch), Tod & Wiederbeleben
- **Monster**: Zombies (greifen an, verbrennen in der Sonne) und Creeper (zischen, blinken, explodieren und sprengen Blöcke weg). Spawnen nachts.
- **Tag/Nacht-Zyklus** (10 Minuten) mit Sonne, Mond, Abendrot und Fackellicht
- **Crafting** mit den **originalen Minecraft-Rezepten**: 2×2 im Inventar, 3×3 an der Werkbank, Muster frei verschiebbar und spiegelbar
- **Ofen** zum Schmelzen (Roheisen → Eisenbarren, Sand → Glas, Bruchstein → Stein, Holz → Holzkohle) mit Brennstoffen
- **Truhen** mit 27 Plätzen
- **Werkzeuge** in Holz/Stein/Eisen/Diamant mit Abbaugeschwindigkeit, Abbaustufen (z.B. Eisenerz braucht Steinspitzhacke) und Haltbarkeit
- **Rezeptbuch** im Spiel (Taste R im Inventar)

### Rezepte (Auswahl)

| Ergebnis | Muster |
|---|---|
| 4 Eichenholzbretter | 1 Eichenstamm (formlos) |
| 4 Stöcke | Bretter über Bretter |
| Werkbank | 2×2 Bretter |
| Truhe | 8 Bretter im Ring |
| Ofen | 8 Bruchstein im Ring |
| 4 Fackeln | Kohle/Holzkohle über Stock |
| Spitzhacke | `MMM / ·S· / ·S·` |
| Axt | `MM / MS / ·S` |
| Schaufel | `M / S / S` |
| Schwert | `M / M / S` |
| Eimer | `I·I / ·I·` (Eisen) |
| Steinziegel, Sandstein, Schneeblock | 2×2 |
| Eisen-/Diamant-/Kohleblock | 3×3 (und zurück) |

`M` = Bretter, Bruchstein, Eisenbarren oder Diamant · `S` = Stock

## Steuerung

| Taste | Aktion |
|---|---|
| WASD / Pfeiltasten | Laufen |
| Leertaste | Springen / im Wasser nach oben schwimmen |
| Strg oder Shift | Sprinten |
| Linke Maustaste (halten) | Abbauen / Angreifen |
| Rechte Maustaste | Platzieren, Werkbank/Ofen/Truhe öffnen, essen, Eimer benutzen |
| 1–9 / Mausrad | Schnellleiste |
| E | Inventar öffnen/schließen |
| R | Rezeptbuch (im Inventar) |
| Q | Item wegwerfen |
| Esc | Maus freigeben / Menü schließen |
| F11 | Vollbild |

Im Inventar: Linksklick = Stapel nehmen/ablegen, Rechtsklick = halbieren bzw. einzeln ablegen, Shift+Klick = schnell verschieben (auch Crafting-Ergebnis: alles craften).

## Starten (Entwicklung)

1. **Godot 4.3 oder neuer** installieren (z.B. `flatpak install flathub org.godotengine.Godot`)
2. Godot öffnen → *Importieren* → `project.godot` in diesem Ordner wählen
3. **F5** drücken

Beim ersten Öffnen importiert Godot das Projekt – das dauert ein paar Sekunden.

## Als RPM bauen (Fedora, openSUSE, RHEL …)

```bash
sudo dnf install rpm-build godot            # openSUSE: sudo zypper install rpm-build godot
chmod +x rpm/build-rpm.sh
./rpm/build-rpm.sh
sudo dnf install ./build/voxelklon-0.1.0-1*.x86_64.rpm
voxelklon                                    # oder über das Anwendungsmenü starten
```

Das Skript exportiert das Spiel mit Godot und packt es als RPM:
- **Mit Godot-Exportvorlagen** (Editor → Exportvorlagen verwalten) entsteht eine eigenständige Spiel-Binärdatei.
- **Ohne Vorlagen** wird nur die Spieldatei (`.pck`) exportiert und das installierte Godot als Laufzeit ins Paket gelegt – funktioniert genauso.

Installiert wird nach `/usr/lib/voxelklon/`, Starter `/usr/bin/voxelklon`, inklusive Menüeintrag und Icon. Entfernen mit `sudo dnf remove voxelklon`.

## Als Flatpak bauen

```bash
# einmalig
sudo apt install flatpak flatpak-builder        # bzw. dnf / pacman
# Godot-Exportvorlagen installieren: Godot-Editor → Editor → Exportvorlagen verwalten → Herunterladen

chmod +x flatpak/build-flatpak.sh
./flatpak/build-flatpak.sh
flatpak run org.voxelklon.VoxelKlon
```

Das Skript
1. exportiert das Spiel mit dem Preset „Linux“ nach `build/linux/`,
2. installiert die Laufzeit `org.freedesktop.Platform//25.08`,
3. baut und installiert das Flatpak und
4. legt zusätzlich `build/VoxelKlon.flatpak` zum Weitergeben an.

Die Flatpak-Dateien liegen in `flatpak/` (Manifest, `.desktop`, Metainfo, Startskript).

## Projektstruktur

```
project.godot, main.tscn, icon.svg
scripts/
  main.gd         Szene, Himmel, Tag/Nacht, Monster-Spawns, Explosionen, Truhen & Öfen
  world.gd        Weltgenerierung (Gelände, Gebirge, Wasser, Höhlen, Erze, Bäume, Dörfer), Chunk-Laden
  chunk.gd        Mesh- und Kollisionsaufbau pro Chunk-Abschnitt
  blocks.gd       Block-Definitionen
  items.gd        Items, Werkzeuge, Icons
  recipes.gd      Crafting- und Ofenrezepte
  texture_gen.gd  Prozedurale 16×16-Texturen
  player.gd       Spieler (Bewegung, Abbauen, Bauen, Kampf, Leben)
  mob.gd          Zombie, Creeper, Villager
  inventory.gd    Inventar
  ui.gd, slot.gd  HUD, Inventar, Crafting, Truhe, Ofen, Rezeptbuch
flatpak/          Flatpak-Paketierung
```

## Einstellungen & Tipps

- **Sichtweite**: `render_radius` in `scripts/world.gd` (Standard 5 Chunks). Kleiner = flüssiger.
- **Tageslänge**: `DAY_LENGTH` in `scripts/main.gd`.
- Wird es ruckelig beim Laufen, liegt das am Chunk-Bau in GDScript – `render_radius` auf 4 senken hilft.

## Bewusste Vereinfachungen

- Die Welt wird nicht gespeichert (jeder Start = neue Welt).
- Wasser fließt vereinfacht (füllt Löcher und fällt nach unten, keine Strömung).
- Abgebaute Blöcke landen direkt im Inventar (keine herumliegenden Items).
- Kein Sound, keine Hunger-Leiste.
