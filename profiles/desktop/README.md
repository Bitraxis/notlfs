# NotLFS Desktop Profile (KDE Plasma)
The Desktop profile provides a full desktop environment with KDE Plasma.

## Features
- Full KDE Plasma desktop environment
- Complete graphics stack (X11 and Wayland)
- Audio support (PulseAudio + ALSA)
- Video playback (ffmpeg, mpv)
- Firefox web browser
- Network management
- Bluetooth support

## Use Cases
- Desktop workstations
- Development machines with GUI
- General-purpose desktop computers

## Default Init System
s6-rc - Dependency-based service manager
Recommended alternative: systemd for best desktop integration

## Build Configuration
./notlfs.sh -p desktop
./notlfs.sh -p desktop -i systemd

## Build Dependencies
Requires on host system:
- X11 development libraries
- Wayland development libraries
- Mesa development libraries
- Qt5 development libraries
- KDE Frameworks 5 development libraries
