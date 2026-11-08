# RPM-Spec für VoxelKlon (Godot-Spiel, bereits exportiert -> nur Dateien verpacken)
%global debug_package %{nil}
%global _build_id_links none
%global __os_install_post %{nil}

Name:           voxelklon
Version:        %{?pkgversion}%{!?pkgversion:0.1.0}
Release:        1%{?dist}
Summary:        Minecraft-artiger Voxel-Klon mit Crafting, Monstern und Dörfern
License:        MIT
BuildArch:      x86_64
AutoReqProv:    no

Source0:        voxelklon-bin
Source1:        VoxelKlon.pck
Source2:        voxelklon.sh
Source3:        org.voxelklon.VoxelKlon.desktop
Source4:        org.voxelklon.VoxelKlon.svg
Source5:        org.voxelklon.VoxelKlon.metainfo.xml

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
Eine unendliche Voxel-Welt mit Gebirgen, Seen, Bäumen und Villager-Dörfern.
Blöcke abbauen, Werkzeuge mit den originalen Minecraft-Rezepten craften,
Erz im Ofen schmelzen und die Nacht gegen Zombies und Creeper überleben.

%prep

%build

%install
install -Dm755 %{SOURCE0} %{buildroot}%{_prefix}/lib/voxelklon/voxelklon-bin
install -Dm644 %{SOURCE1} %{buildroot}%{_prefix}/lib/voxelklon/VoxelKlon.pck
install -Dm755 %{SOURCE2} %{buildroot}%{_bindir}/voxelklon
install -Dm644 %{SOURCE3} %{buildroot}%{_datadir}/applications/org.voxelklon.VoxelKlon.desktop
install -Dm644 %{SOURCE4} %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/org.voxelklon.VoxelKlon.svg
install -Dm644 %{SOURCE5} %{buildroot}%{_datadir}/metainfo/org.voxelklon.VoxelKlon.metainfo.xml

%files
%{_prefix}/lib/voxelklon/
%{_bindir}/voxelklon
%{_datadir}/applications/org.voxelklon.VoxelKlon.desktop
%{_datadir}/icons/hicolor/scalable/apps/org.voxelklon.VoxelKlon.svg
%{_datadir}/metainfo/org.voxelklon.VoxelKlon.metainfo.xml

%changelog
* Sun Nov 08 2026 VoxelKlon <voxelklon@localhost> - 0.1.0-1
- Erste Version
