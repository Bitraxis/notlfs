# NotLFS Minimal Profile
The Minimal profile provides the absolute bare essentials for a bootable Linux system.

## Features
- Smallest possible NotLFS installation
- Fast build time (30-60 minutes)
- Minimal disk footprint (300-500 MB)
- Security hardening enabled by default

## Use Cases
- Embedded systems
- Container images
- Rescue/recovery systems
- Custom builds with maximum control

## Default Init System
s6 - Minimalist supervision suite
Alternative: s6-rc, dinit, runit, sysv

## Build Configuration
./notlfs.sh -p minimal -i s6
./notlfs.sh -p minimal -i s6-rc
