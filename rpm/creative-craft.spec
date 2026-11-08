# RPM-Spec für Creative Craft (Godot-Spiel, bereits exportiert -> nur Dateien verpacken)
%global debug_package %{nil}
%global _build_id_links none
%global __os_install_post %{nil}
%global appid org.creativecraft.CreativeCraft

Name:           creative-craft
Version:        %{?pkgversion}%{!?pkgversion:0.3.0}
Release:        1%{?dist}
Summary:        Bauen, craften und überleben in einer Voxel-Welt
License:        MIT
BuildArch:      x86_64
AutoReqProv:    no

Source0:        creative-craft-bin
Source1:        CreativeCraft.pck
Source2:        creative-craft.sh
Source3:        %{appid}.desktop
Source4:        icons.tar
Source5:        %{appid}.metainfo.xml

# Godot lädt Grafik-/Audio-Bibliotheken zur Laufzeit (Namen wie unter Fedora)
Recommends:     mesa-libGL
Recommends:     vulkan-loader
Recommends:     mesa-vulkan-drivers
Recommends:     libXcursor
Recommends:     libXinerama
Recommends:     libXrandr
Recommends:     libXi
Recommends:     alsa-lib
Recommends:     pulseaudio-libs

%description
Creative Craft: eine unendliche Voxel-Welt mit Gebirgen, Seen, Bäumen und
Villager-Dörfern. Blöcke abbauen, Werkzeuge mit den originalen
Minecraft-Rezepten craften, Erz im Ofen schmelzen und die Nacht gegen
Zombies und Creeper überleben.

%prep

%build

%install
install -Dm755 %{SOURCE0} %{buildroot}%{_prefix}/lib/creative-craft/creative-craft-bin
install -Dm644 %{SOURCE1} %{buildroot}%{_prefix}/lib/creative-craft/CreativeCraft.pck
install -Dm755 %{SOURCE2} %{buildroot}%{_bindir}/creative-craft
install -Dm644 %{SOURCE3} %{buildroot}%{_datadir}/applications/%{appid}.desktop
install -Dm644 %{SOURCE5} %{buildroot}%{_datadir}/metainfo/%{appid}.metainfo.xml
mkdir -p icons && tar -xf %{SOURCE4} -C icons
for s in 32 48 64 128 256 512; do
  install -Dm644 icons/icon-$s.png %{buildroot}%{_datadir}/icons/hicolor/${s}x${s}/apps/%{appid}.png
done

%files
%{_prefix}/lib/creative-craft/
%{_bindir}/creative-craft
%{_datadir}/applications/%{appid}.desktop
%{_datadir}/metainfo/%{appid}.metainfo.xml
%{_datadir}/icons/hicolor/*/apps/%{appid}.png

%changelog
* Sun Nov 08 2026 Creative Craft <creativecraft@localhost> - 0.3.0-1
- Speichern/Laden, Schafe, Bett, Schere, TNT, Feuerzeug, Farbstoffe, Steuerung im Esc-Menü
* Sun Nov 08 2026 Creative Craft <creativecraft@localhost> - 0.2.0-1
- Umbenannt in Creative Craft, Startmenü, animierte Hand, Menü-Icons
* Sun Nov 08 2026 Creative Craft <creativecraft@localhost> - 0.1.0-1
- Erste Version
