# NotLFS Base Profile
The Base profile provides a complete Linux system with development tools and networking.

## Features
- Complete Linux system with all essential packages
- Full development toolchain
- Networking support
- Version control systems
- System monitoring tools
- Multiple programming languages
- Security hardening enabled
- Documentation included

## Use Cases
- Development workstations
- General-purpose servers
- Base for custom distributions

## Default Init System
s6-rc - Dependency-based service manager
Alternative: s6, dinit, runit, sysv, systemd, openrc

## Build Configuration
./notlfs.sh -p base
./notlfs.sh -p base -i runit
