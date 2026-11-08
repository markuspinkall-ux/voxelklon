# Creative Craft – ein Minecraft-artiges Spiel in Godot 4

Komplett in GDScript, ohne externe Assets: alle Texturen und Icons werden beim Start prozedural erzeugt.

## Download

Fertige Builds (automatisch bei jedem Push gebaut): **https://github.com/markuspinkall-ux/voxelklon/releases/tag/latest**

- Flatpak: `flatpak install --user CreativeCraft.flatpak` → `flatpak run org.creativecraft.CreativeCraft`
- RPM: `sudo dnf install ./creative-craft-0.2.0-1.x86_64.rpm` → `creative-craft`

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
- **Speichern & Laden**: mehrere Welten, automatisches Speichern alle 3 Minuten und beim Verlassen; gespeichert werden veränderte Chunks, Inventar, Position, Truhen, Öfen, Uhrzeit
- **Startmenü** (Weltname, Seed, Sichtweite, Welt laden/löschen, Steuerung) und **Pause-Menü** (Esc: Weiterspielen, Speichern, Steuerung, Hauptmenü, Beenden) im Graphit-Stil von Creative OS
- **Schafe**: geben beim Töten Wolle + Hammelfleisch, mit der Schere geschoren 1–3 Wolle (wächst nach)
- **Bett**: nachts schlafen (überspringt die Nacht, nicht wenn Monster in der Nähe sind) und Wiedereinstiegspunkt setzen
- **TNT** mit Feuerzeug zünden (4 s Zündschnur, Kettenreaktionen); Feuerstein aus Kies
- **Animierte Hand** in der Ego-Ansicht: Arm mit leerer Hand, Werkzeug oder Block in der Hand, Schwung beim Abbauen/Schlagen/Bauen, Wippen beim Laufen

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
| Bett | `WWW / PPP` (3 gleichfarbige Wolle über 3 Brettern, Werkbank) |
| Schere | `·I / I·` (2 Eisenbarren diagonal) |
| Feuerzeug | Eisenbarren + Feuerstein (formlos) |
| TNT | `GSG / SGS / GSG` (5 Schwarzpulver, 4 Sand) |
| Roter / Gelber Farbstoff | Mohn / Löwenzahn (formlos) |
| Rote / Gelbe Wolle | Farbstoff + weiße Wolle (formlos) |
| Gebratenes Hammelfleisch | rohes Hammelfleisch im Ofen |
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
| Rechte Maustaste | Platzieren, Werkbank/Ofen/Truhe öffnen, essen, schlafen, Schaf scheren, TNT zünden, Eimer |
| 1–9 / Mausrad | Schnellleiste |
| E | Inventar öffnen/schließen |
| R | Rezeptbuch (im Inventar) |
| Q | Item wegwerfen |
| Esc | Pause-Menü (dort auch „Steuerung“ und „Speichern“) |
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
sudo dnf install ./build/creative-craft-0.2.0-1*.x86_64.rpm
creative-craft                               # oder über das Anwendungsmenü starten
```

Das Skript exportiert das Spiel mit Godot und packt es als RPM:
- **Mit Godot-Exportvorlagen** (Editor → Exportvorlagen verwalten) entsteht eine eigenständige Spiel-Binärdatei.
- **Ohne Vorlagen** wird nur die Spieldatei (`.pck`) exportiert und das installierte Godot als Laufzeit ins Paket gelegt – funktioniert genauso.

Installiert wird nach `/usr/lib/creative-craft/`, Starter `/usr/bin/creative-craft`, inklusive Menüeintrag und Icon. Entfernen mit `sudo dnf remove creative-craft`.

## Als Flatpak bauen

```bash
# einmalig
sudo apt install flatpak flatpak-builder        # bzw. dnf / pacman
# Godot-Exportvorlagen installieren: Godot-Editor → Editor → Exportvorlagen verwalten → Herunterladen

chmod +x flatpak/build-flatpak.sh
./flatpak/build-flatpak.sh
flatpak run org.creativecraft.CreativeCraft
```

Das Skript
1. exportiert das Spiel mit dem Preset „Linux“ nach `build/linux/`,
2. installiert die Laufzeit `org.freedesktop.Platform//25.08`,
3. baut und installiert das Flatpak und
4. legt zusätzlich `build/CreativeCraft.flatpak` zum Weitergeben an.

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
  menu.gd         Startmenü (Neue Welt, Laden, Steuerung)
  controls.gd     Steuerungstext
  block_mesh.gd   Einzelblock-Mesh (Hand, gezündetes TNT)
  hand.gd         Animierte Hand / gehaltenes Item
  inventory.gd    Inventar
  ui.gd, slot.gd  HUD, Inventar, Crafting, Truhe, Ofen, Rezeptbuch
flatpak/          Flatpak-Paketierung
rpm/              RPM-Paketierung
icons/            App-Icons (PNG, aus icon.svg)
```

## Einstellungen & Tipps

- **Sichtweite**: `render_radius` in `scripts/world.gd` (Standard 5 Chunks). Kleiner = flüssiger.
- **Tageslänge**: `DAY_LENGTH` in `scripts/main.gd`.
- Wird es ruckelig beim Laufen, liegt das am Chunk-Bau in GDScript – `render_radius` auf 4 senken hilft.

## Bewusste Vereinfachungen

- Wasser fließt vereinfacht (füllt Löcher und fällt nach unten, keine Strömung).
- Abgebaute Blöcke landen direkt im Inventar (keine herumliegenden Items).
- Kein Sound, keine Hunger-Leiste.
- Betten sind 1 Block groß (im Original 2), Tiere werden nicht mitgespeichert (sie erscheinen beim Laden neu).
- Spielstände liegen unter `~/.local/share/godot/app_userdata/Creative Craft/saves/` (Flatpak: `~/.var/app/org.creativecraft.CreativeCraft/data/godot/app_userdata/Creative Craft/saves/`).
