#!/bin/bash
# =============================================================================
# NotLFS Build Profiles
# =============================================================================
#
# This file contains the four build profiles requested for the NotLFS framework:
#   1. minimal   - Absolute minimal system with only essential packages
#   2. base      - Base system with development tools and networking
#   3. desktop   - Full desktop environment with KDE Plasma
#   4. server    - Server-oriented system with web and database services
#
# Each profile includes:
#   - Package selections (categories and individual packages)
#   - Default init system recommendation
#   - Feature flags (minimal, network, development, desktop, server)
#   - Service definitions for the recommended init system
#   - Custom configuration files
#   - Build hooks (pre-build, post-build, post-install)
#   - Documentation
#
# USAGE:
#   Copy this file to your NotLFS profiles directory and source it:
#   source notlfs-profiles.sh
#
#   Or use the profile files directly in your ${PROFILES_DIR}:
#   cp profiles/* ${PROFILES_DIR}/
#
#   Then select a profile with:
#   ./notlfs.sh -p minimal
#   ./notlfs.sh --profile desktop --init s6-rc
#
# PROFILE STRUCTURE:
#   Each profile is stored in: ${PROFILES_DIR}/${PROFILE_NAME}/
#   Each profile contains:
#     - profile.xml          Main profile definition (XML format)
#     - packages.list        List of packages to install
#     - services/            Init system service definitions
#     - config/              Custom configuration files
#     - hooks/               Build hooks (pre, post)
#     - README.md            Profile documentation
#
# =============================================================================

# This script creates all four profile directories with their complete definitions
# Run this from your NotLFS root directory or set NOTLFS_ROOT

set -o errexit
set -o nounset
set -o pipefail

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTLFS_ROOT="${NOTLFS_ROOT:-${SCRIPT_DIR}}"
PROFILES_DIR="${NOTLFS_ROOT}/profiles"
PACKAGES_DIR="${NOTLFS_ROOT}/packages"
CONFIG_DIR="${NOTLFS_ROOT}/configs"

# Ensure directories exist
mkdir -p "${PROFILES_DIR}"
mkdir -p "${PACKAGES_DIR}"
mkdir -p "${CONFIG_DIR}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_section() {
    echo ""
    echo "============================================================================"
    echo "  $1"
    echo "============================================================================"
}

# =============================================================================
# PROFILE CREATION FUNCTIONS
# =============================================================================

create_profile_directory() {
    local profile_name="$1"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    
    log_info "Creating profile directory: ${profile_dir}"
    mkdir -p "${profile_dir}/services"
    mkdir -p "${profile_dir}/config"
    mkdir -p "${profile_dir}/hooks"
    mkdir -p "${profile_dir}/scripts"
}

# =============================================================================
# PROFILE 1: MINIMAL
# =============================================================================
#
# The minimal profile provides the absolute bare essentials for a bootable
# Linux system. It includes only the core toolchain and essential utilities
# needed for the system to function.
#
# Use case: Embedded systems, containers, rescue systems, or as a base
#           for custom builds with maximum control
#
# Default init system: s6 (minimalist supervision suite)
# Estimated build time: 30-60 minutes
# Estimated disk space: 300-500 MB
#

create_minimal_profile() {
    local profile_name="minimal"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    
    log_section "Creating MINIMAL Profile"
    create_profile_directory "$profile_name"
    
    # Create profile.xml
    cat > "${profile_dir}/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!--
    NotLFS Minimal Profile
    =====================
    Absolute minimal Linux system with only essential packages.
    Perfect for embedded systems, containers, or as a foundation.
-->
<profile name="minimal">
    <description>Absolute minimal NotLFS system with only essential packages for a bootable Linux</description>
    <author>NotLFS Team</author>
    <version>1.0</version>
    
    <!-- Recommended init system - lightweight and minimal -->
    <init_system>s6</init_system>
    
    <!-- Supported init systems -->
    <supported_init_systems>
        <init>s6</init>
        <init>s6-rc</init>
        <init>dinit</init>
        <init>runit</init>
        <init>sysv</init>
    </supported_init_systems>
    
    <!-- Package selections -->
    <packages>
        <!-- Core system (required for all profiles) -->
        <include category="core" />
        
        <!-- Init system packages -->
        <include category="init" />
        
        <!-- Essential utilities -->
        <package name="util-linux" enabled="true" />
        <package name="e2fsprogs" enabled="true" />
        <package name="iana-etc" enabled="true" />
        
        <!-- Basic shell utilities -->
        <package name="bash" enabled="true" />
        <package name="coreutils" enabled="true" />
        <package name="diffutils" enabled="true" />
        <package name="findutils" enabled="true" />
        <package name="gawk" enabled="true" />
        <package name="grep" enabled="true" />
        <package name="gzip" enabled="true" />
        <package name="sed" enabled="true" />
        <package name="tar" enabled="true" />
        <package name="xz" enabled="true" />
        
        <!-- Basic networking (minimal) -->
        <package name="iproute2" enabled="false" />
        <package name="curl" enabled="false" />
        <package name="wget" enabled="false" />
    </packages>
    
    <!-- Feature flags -->
    <features>
        <feature name="minimal">true</feature>
        <feature name="network">false</feature>
        <feature name="development">false</feature>
        <feature name="desktop">false</feature>
        <feature name="server">false</feature>
        <feature name="hardening">true</feature>
        <feature name="strip_debug">true</feature>
    </features>
    
    <!-- Build configuration -->
    <build>
        <optimization>-Os -pipe</optimization>
        <jobs>$(nproc)</jobs>
        <strip_debug>true</strip_debug>
        <keep_sources>false</keep_sources>
    </build>
    
    <!-- Security hardening -->
    <security>
        <stack_protector>true</stack_protector>
        <fortify_source>true</fortify_source>
        <relro>true</relro>
        <aslr>true</aslr>
        <pie>true</pie>
    </security>
    
    <!-- Hooks -->
    <hooks>
        <hook stage="pre-toolchain">
            echo "Building minimal profile - optimizing for size"
        </hook>
        <hook stage="post-system">
            # Create minimal /etc/issue
            echo "NotLFS Minimal" > ${LFS}/etc/issue
            echo "Kernel \r on an \m" >> ${LFS}/etc/issue
        </hook>
        <hook stage="post-install">
            # Set minimal hostname
            echo "notlfs-minimal" > ${LFS}/etc/hostname
        </hook>
    </hooks>
</profile>
EOF
    
    # Create packages.list (explicit package list)
    cat > "${profile_dir}/packages.list" << 'EOF'
# NotLFS Minimal Profile - Package List
# =====================================
# This file lists all packages included in the minimal profile.
# Packages are organized by build stage.

# Stage 1: Toolchain (required)
binutils
gcc
linux-headers
glibc

# Stage 2: Core system (required)
bash
coreutils
diffutils
file
findutils
gawk
grep
m4
make
patch
sed
tar
xz

# Stage 3: Essential utilities
util-linux
e2fsprogs
iana-etc

# Stage 4: Init system (s6 by default)
s6
EOF
    
    # Create README.md for the profile
    cat > "${profile_dir}/README.md" << 'EOF'
# NotLFS Minimal Profile

## Overview

The **Minimal** profile provides the absolute bare essentials for a bootable Linux system. It includes only the core toolchain, essential utilities, and a minimal init system.

## Features

- ✅ Smallest possible NotLFS installation
- ✅ Fast build time (~30-60 minutes)
- ✅ Minimal disk footprint (~300-500 MB)
- ✅ No unnecessary services or daemons
- ✅ Security hardening enabled by default
- ✅ Debug symbols stripped for size optimization

## Use Cases

- Embedded systems
- Container images
- Rescue/recovery systems
- Custom builds with maximum control
- Educational purposes (understanding Linux internals)

## Default Init System

**s6** - A minimalist supervision suite that provides process supervision without the complexity of larger init systems.

Alternative supported init systems:
- s6-rc (recommended for dependency management)
- dinit (fast, dependency-based)
- runit (simple, reliable)
- sysv (traditional)

## Package Selection

### Included Categories
- `core` - Core system packages (toolchain, glibc, etc.)
- `init` - Init system packages

### Individual Packages
- util-linux - Essential Linux utilities
- e2fsprogs - ext2/3/4 filesystem utilities
- iana-etc - Network configuration files
- bash, coreutils, diffutils, findutils, gawk, grep, sed, tar, xz - Essential shell utilities

### Excluded by Default
- Networking tools (iproute2, curl, wget)
- Development tools (gcc after toolchain, make, etc.)
- Desktop environments
- Server software

## Customization

To add packages to the minimal profile, create a custom profile that includes this one:

```xml
<profile name="my-minimal">
    <include profile="minimal" />
    <packages>
        <package name="curl" />
        <package name="vim" />
    </packages>
</profile>
```

## Build Configuration

```bash
# Build with minimal profile
./notlfs.sh -p minimal -i s6

# Build with s6-rc (recommended for service management)
./notlfs.sh -p minimal -i s6-rc

# Build with optimization for embedded systems
./notlfs.sh -p minimal -i dinit --optimization -Os
```

## Post-Installation

After installation, you'll have a minimal Linux system. To add more packages:

```bash
# Using the NotLFS post-install environment
chroot /mnt/notlfs /usr/local/notlfs/bin/notlfs.sh -m manual

# Or manually
chroot /mnt/notlfs /bin/bash
apt-get update && apt-get install <package>  # If using a package manager
```

## Notes

- This profile does NOT include networking by default. To enable networking, add the `network` category or individual networking packages.
- No package manager is included by default. Use the `notlfs-pkg-manager` to add one post-install.
- The system will boot to a basic shell prompt with no services running.
EOF
    
    # Create service definitions for s6
    mkdir -p "${profile_dir}/services/s6"
    cat > "${profile_dir}/services/s6/README.md" << 'EOF'
# Minimal Profile - s6 Service Definitions

This directory contains service definitions for the s6 init system when using the minimal profile.

## Default Services

The minimal profile includes only the most essential services:

1. **s6-svscan** - The s6 service supervisor
2. **s6-rc-init** - s6-rc initialization (if using s6-rc)

## Service Files

Each service has the following structure:

```
/etc/s6/<service-name>/
├── run       # Executable script to start the service
├── finish    # Optional: script to run when service exits
└── log/
    ├── run    # Script to handle service logging
    └── ...
```

## Adding Services

To add a service to the minimal profile:

1. Create a service directory:
   ```bash
   mkdir -p /etc/s6/my-service
   ```

2. Create the run script:
   ```bash
   cat > /etc/s6/my-service/run << 'SCRIPT'
   #!/bin/sh
   exec my-service-command --options
   SCRIPT
   chmod +x /etc/s6/my-service/run
   ```

3. Link to current:
   ```bash
   ln -s /etc/s6/my-service /etc/s6/current/my-service
   ```

4. Update the database (for s6-rc):
   ```bash
   s6-rc-db update
   ```
EOF
    
    # Create config files
    cat > "${profile_dir}/config/minimal.conf" << 'EOF'
# NotLFS Minimal Profile Configuration
# =====================================

# Build options
BUILD_OPTIMIZATION="-Os -pipe"
STRIP_DEBUG="true"
KEEP_SOURCES="false"

# System options
HOSTNAME="notlfs-minimal"
TIMEZONE="UTC"
LOCALE="C.UTF-8"

# Network options (disabled by default)
ENABLE_NETWORK="false"
NETWORK_INTERFACES=""

# Security options
ENABLE_HARDENING="true"
STACK_PROTECTOR="true"
FORTIFY_SOURCE="true"
RELRO="true"
ASLR="true"
PIE="true"

# Init system
INIT_SYSTEM="s6"
EOF
    
    # Create hooks
    cat > "${profile_dir}/hooks/pre-build.sh" << 'EOF'
#!/bin/bash
# Minimal Profile - Pre-Build Hook
# This hook runs before the build process starts

set -e

echo "=== Minimal Profile: Pre-Build Hook ==="

# Set optimization flags for minimal size
if [ -z "$OPTIMIZATION" ]; then
    export OPTIMIZATION="-Os -pipe"
    echo "Set optimization: $OPTIMIZATION"
fi

# Enable stripping of debug symbols
if [ "$STRIP_DEBUG" != "false" ]; then
    export STRIP_DEBUG="true"
    echo "Enabled debug symbol stripping"
fi

# Disable networking packages
if [ -z "$DISABLE_NETWORK" ]; then
    export DISABLE_NETWORK="true"
    echo "Networking packages disabled"
fi

# Set minimal hostname
export HOSTNAME="notlfs-minimal"

echo "=== Minimal Profile: Pre-Build Complete ==="
EOF
    chmod +x "${profile_dir}/hooks/pre-build.sh"
    
    cat > "${profile_dir}/hooks/post-install.sh" << 'EOF'
#!/bin/bash
# Minimal Profile - Post-Install Hook
# This hook runs after all packages are installed

set -e

echo "=== Minimal Profile: Post-Install Hook ==="

# Create minimal /etc/issue
cat > ${LFS}/etc/issue << 'ISSUE'
NotLFS Minimal
Kernel \r on an \m
ISSUE

# Create minimal /etc/motd
cat > ${LFS}/etc/motd << 'MOTD'
Welcome to NotLFS Minimal
Type 'help' for available commands
MOTD

# Set minimal hostname
echo "notlfs-minimal" > ${LFS}/etc/hostname

# Create basic shell profile
cat > ${LFS}/etc/profile << 'PROFILE'
# Minimal shell profile
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PS1='\u@\h:\w\$ '
PROFILE

# Configure bash
cat > ${LFS}/etc/bashrc << 'BASHRC'
# Minimal bash configuration
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
export PS1='\u@\h:\w\$ '
BASHRC

# Create /etc/fstab (minimal)
cat > ${LFS}/etc/fstab << 'FSTAB'
# Minimal fstab
proc    /proc   proc    defaults        0       0
sysfs   /sys    sysfs   defaults        0       0
devpts  /dev/pts devpts  gid=5,mode=620 0       0
tmpfs   /dev/shm tmpfs  defaults        0       0
FSTAB

# Setup s6 init system
if [ "$INIT_SYSTEM" = "s6" ] || [ "$INIT_SYSTEM" = "s6-rc" ]; then
    echo "Configuring s6 init system..."
    
    # Create /etc/s6 directory structure
    mkdir -p ${LFS}/etc/s6/current
    
    # Create s6-svscan service
    mkdir -p ${LFS}/etc/s6/s6-svscan
    cat > ${LFS}/etc/s6/s6-svscan/run << 'RUN'
#!/bin/sh
exec s6-svscan /etc/s6/current
RUN
    chmod +x ${LFS}/etc/s6/s6-svscan/run
    
    # Link to current
    ln -sf /etc/s6/s6-svscan ${LFS}/etc/s6/current/s6-svscan
    
    # Create /run directory
    mkdir -p ${LFS}/run
    
    # Create inittab symlink for s6
    ln -sf /bin/s6-svscan ${LFS}/sbin/init
    
    echo "s6 init system configured"
fi

echo "=== Minimal Profile: Post-Install Complete ==="
EOF
    chmod +x "${profile_dir}/hooks/post-install.sh"
    
    log_info "Minimal profile created successfully"
}

# =============================================================================
# PROFILE 2: BASE
# =============================================================================
#
# The base profile provides a complete Linux system with development tools,
# networking support, and essential utilities. It's suitable for general
# purpose use as a server or development workstation.
#
# Use case: General-purpose Linux system, development workstation,
#           or as a base for further customization
#
# Default init system: s6-rc (dependency-based service management)
# Estimated build time: 2-4 hours
# Estimated disk space: 1.5-2.5 GB
#

create_base_profile() {
    local profile_name="base"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    
    log_section "Creating BASE Profile"
    create_profile_directory "$profile_name"
    
    # Create profile.xml
    cat > "${profile_dir}/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!--
    NotLFS Base Profile
    ==================
    Complete Linux system with development tools and networking.
    Suitable for general purpose use as a server or workstation.
-->
<profile name="base">
    <description>Complete NotLFS system with development tools, networking, and essential utilities</description>
    <author>NotLFS Team</author>
    <version>1.0</version>
    
    <!-- Recommended init system - dependency-based service management -->
    <init_system>s6-rc</init_system>
    
    <!-- Supported init systems -->
    <supported_init_systems>
        <init>s6</init>
        <init>s6-rc</init>
        <init>dinit</init>
        <init>runit</init>
        <init>sysv</init>
        <init>systemd</init>
        <init>openrc</init>
    </supported_init_systems>
    
    <!-- Package selections -->
    <packages>
        <!-- Core system (required) -->
        <include category="core" />
        
        <!-- Init system -->
        <include category="init" />
        
        <!-- Development tools -->
        <include category="dev" />
        
        <!-- Essential utilities -->
        <include category="utils" />
        
        <!-- Networking -->
        <include category="network" />
        
        <!-- Programming languages -->
        <include category="languages" />
        
        <!-- Additional base packages -->
        <package name="vim" enabled="true" />
        <package name="nano" enabled="true" />
        <package name="less" enabled="true" />
        <package name="man-db" enabled="true" />
        <package name="info" enabled="true" />
        <package name="bzip2" enabled="true" />
        <package name="file" enabled="true" />
        <package name="which" enabled="true" />
        <package name="gettext" enabled="true" />
        <package name="intltool" enabled="true" />
        <package name="autoconf" enabled="true" />
        <package name="automake" enabled="true" />
        <package name="libtool" enabled="true" />
        <package name="pkg-config" enabled="true" />
        <package name="cmake" enabled="true" />
        <package name="ninja" enabled="true" />
        <package name="meson" enabled="true" />
        
        <!-- Networking tools -->
        <package name="iproute2" enabled="true" />
        <package name="iputils" enabled="true" />
        <package name="net-tools" enabled="true" />
        <package name="curl" enabled="true" />
        <package name="wget" enabled="true" />
        <package name="openssh" enabled="true" />
        <package name="openssl" enabled="true" />
        <package name="ca-certificates" enabled="true" />
        
        <!-- System monitoring -->
        <package name="procps" enabled="true" />
        <package name="psmisc" enabled="true" />
        <package name="sysstat" enabled="true" />
        <package name="htop" enabled="true" />
        
        <!-- File system tools -->
        <package name="dosfstools" enabled="true" />
        <package name="reiserfsprogs" enabled="false" />
        <package name="xfsprogs" enabled="false" />
        <package name="ntfs-3g" enabled="false" />
        
        <!-- Text processing -->
        <package name="groff" enabled="false" />
        <package name="texinfo" enabled="true" />
        
        <!-- Compression -->
        <package name="zstd" enabled="true" />
        <package name="lzma" enabled="true" />
        <package name="lz4" enabled="false" />
    </packages>
    
    <!-- Feature flags -->
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
        <feature name="desktop">false</feature>
        <feature name="server">false</feature>
        <feature name="hardening">true</feature>
        <feature name="strip_debug">false</feature>
        <feature name="documents">true</feature>
    </features>
    
    <!-- Build configuration -->
    <build>
        <optimization>-O2 -pipe</optimization>
        <jobs>$(nproc)</jobs>
        <strip_debug>false</strip_debug>
        <keep_sources>false</keep_sources>
    </build>
    
    <!-- Security hardening -->
    <security>
        <stack_protector>true</stack_protector>
        <fortify_source>true</fortify_source>
        <relro>true</relro>
        <aslr>true</aslr>
        <pie>true</pie>
    </security>
    
    <!-- Network configuration -->
    <network>
        <hostname>notlfs-base</hostname>
        <domain>local</domain>
        <enable_dhcp>true</enable_dhcp>
        <nameservers>8.8.8.8 8.8.4.4</nameservers>
    </network>
    
    <!-- Hooks -->
    <hooks>
        <hook stage="pre-toolchain">
            echo "Building base profile - standard optimization"
        </hook>
        <hook stage="post-system">
            # Enable networking
            echo "Enabling networking support"
        </hook>
        <hook stage="post-install">
            # Setup network configuration
            echo "Configuring network..."
        </hook>
    </hooks>
</profile>
EOF
    
    # Create packages.list
    cat > "${profile_dir}/packages.list" << 'EOF'
# NotLFS Base Profile - Package List
# =================================
# Complete Linux system with development tools and networking

# Stage 1: Toolchain
binutils
gcc
linux-headers
glibc

# Stage 2: Core system
bash
coreutils
diffutils
file
findutils
gawk
grep
m4
make
patch
sed
tar
xz

# Stage 3: Essential utilities
util-linux
e2fsprogs
iana-etc
vim
nano
less
man-db
info
bzip2
file
which
gettext
intltool

# Stage 4: Development tools
autoconf
automake
libtool
pkg-config
cmake
ninja
meson
git
mercurial
subversion

# Stage 5: Networking
iproute2
iputils
net-tools
curl
wget
openssh
openssl
ca-certificates

# Stage 6: System monitoring
procps
psmisc
sysstat
htop

# Stage 7: Init system (s6-rc)
s6
s6-rc
skalibs

# Stage 8: Programming languages
python
perl
ruby

# Stage 9: Compression
zstd
lzma
EOF
    
    # Create README.md
    cat > "${profile_dir}/README.md" << 'EOF'
# NotLFS Base Profile

## Overview

The **Base** profile provides a complete Linux system with development tools, networking support, and essential utilities. It's suitable for general-purpose use as a server, development workstation, or as a base for further customization.

## Features

- ✅ Complete Linux system with all essential packages
- ✅ Full development toolchain (gcc, make, autotools, cmake, etc.)
- ✅ Networking support with common tools
- ✅ Version control systems (git, mercurial, subversion)
- ✅ System monitoring tools (htop, procps, sysstat)
- ✅ Multiple programming languages (Python, Perl, Ruby)
- ✅ Security hardening enabled
- ✅ Documentation included

## Use Cases

- Development workstations
- General-purpose servers
- Base for custom distributions
- Learning and experimentation
- Replacement for traditional Linux distributions

## Default Init System

**s6-rc** - A dependency-based service manager for s6 that provides:
- Service dependency management
- Process supervision
- Service state tracking
- Clean and predictable behavior

Alternative supported init systems:
- s6 - Minimalist supervision suite
- dinit - Fast, dependency-based init
- runit - Simple, reliable service supervisor
- sysv - Traditional SysV init
- systemd - Full-featured system and service manager
- openrc - OpenRC init system (Gentoo-style)

## Package Selection

### Included Categories
- `core` - Core system packages
- `init` - Init system packages
- `dev` - Development tools
- `utils` - Essential utilities
- `network` - Networking support
- `languages` - Programming languages

### Additional Packages
- **Editors**: vim, nano
- **Documentation**: man-db, info, texinfo
- **Compression**: bzip2, zstd, lzma
- **Networking**: iproute2, iputils, net-tools, curl, wget, openssh, openssl
- **Development**: autoconf, automake, libtool, pkg-config, cmake, ninja, meson
- **Version Control**: git, mercurial, subversion
- **Monitoring**: procps, psmisc, sysstat, htop

### Excluded by Default
- Desktop environments
- Graphical applications
- Web servers
- Database servers
- Container tools

## Customization

To customize the base profile, you can:

1. **Add packages** by including them in your configuration:
   ```xml
   <profile name="my-base">
       <include profile="base" />
       <packages>
           <package name="nginx" />
           <package name="postgresql" />
       </packages>
   </profile>
   ```

2. **Remove packages** by disabling them:
   ```xml
   <profile name="my-base">
       <include profile="base" />
       <packages>
           <package name="vim" enabled="false" />
           <package name="emacs" enabled="false" />
       </packages>
   </profile>
   ```

3. **Change the init system**:
   ```bash
   ./notlfs.sh -p base -i systemd
   ```

## Build Configuration

```bash
# Build with base profile (default)
./notlfs.sh -p base

# Build with specific init system
./notlfs.sh -p base -i runit

# Build with custom optimization
./notlfs.sh -p base --optimization -O3

# Build in auto mode (unattended)
./notlfs.sh -p base -m auto

# Build in manual mode (step-by-step)
./notlfs.sh -p base -m manual
```

## Post-Installation

After installation, you'll have a complete Linux system ready for use.

### Setting up networking

```bash
# Configure network interface (example for eth0)
ip link set eth0 up
ip addr add 192.168.1.100/24 dev eth0
ip route add default via 192.168.1.1

# Or use DHCP
udhcpc -i eth0

# Test connectivity
ping google.com
```

### Adding a package manager

```bash
# Using the NotLFS package manager adder
chroot /mnt/notlfs /usr/local/notlfs/bin/pkg-manager.sh install xbps

# Or manually
chroot /mnt/notlfs /bin/bash
# Follow package manager installation instructions
```

### Creating a user

```bash
chroot /mnt/notlfs /bin/bash
useradd -m -G wheel,audio,video,storage myuser
passwd myuser
visudo  # Uncomment %wheel ALL=(ALL) ALL
```

## Service Management

With s6-rc (default init system):

```bash
# List all services
s6-rc-db list

# Check service status
s6-rc -a list

# Start a service
s6-rc -u change <service>

# Stop a service
s6-rc -d change <service>

# Enable a service at boot
ln -s /etc/s6-rc/databases/available/<service> /etc/s6-rc/databases/current/<service>
```

## Notes

- This profile includes documentation (man pages, info pages) by default. To exclude them for size savings, set `feature name="documents">false</feature>`.
- The build process may take 2-4 hours depending on your hardware.
- Disk space requirement is approximately 1.5-2.5 GB.
- All source code is downloaded and compiled from scratch.
EOF
    
    # Create service definitions for s6-rc
    mkdir -p "${profile_dir}/services/s6-rc"
    cat > "${profile_dir}/services/s6-rc/README.md" << 'EOF'
# Base Profile - s6-rc Service Definitions

This directory contains service definitions for the s6-rc init system when using the base profile.

## Default Services

The base profile includes the following services:

1. **s6-rc-init** - s6-rc initialization
2. **s6-svscan** - s6 service supervisor
3. **s6-rc-update** - s6-rc database update
4. **cronie** - Cron daemon (optional)
5. **openssh** - SSH server (optional)

## Service Structure

Each service in s6-rc has two main components:

1. **Service directory** (`/etc/s6/<service-name>/`):
   - `run` - Script to start the service
   - `finish` - Script to run when service exits
   - `log/run` - Script to handle logging

2. **Database entry** (`/etc/s6-rc/databases/available/<service-name>`):
   - Defines service dependencies
   - Specifies service type (oneshot, longrun, bundle)
   - Contains service configuration

## Example: openssh Service

To create an openssh service:

1. Create the service directory:
   ```bash
   mkdir -p /etc/s6/openssh
   ```

2. Create the run script (`/etc/s6/openssh/run`):
   ```bash
   #!/bin/sh
   exec /usr/bin/sshd -D
   ```

3. Create the finish script (`/etc/s6/openssh/finish`):
   ```bash
   #!/bin/sh
   exec s6-notifywhenup "$1"
   ```

4. Create the log directory:
   ```bash
   mkdir -p /etc/s6/openssh/log
   cat > /etc/s6/openssh/log/run << 'LOG'
   #!/bin/sh
   exec s6-log /var/log/openssh
   LOG
   chmod +x /etc/s6/openssh/log/run
   ```

5. Create the database entry (`/etc/s6-rc/databases/available/openssh`):
   ```bash
   #!/bin/sh
   exec s6-rc -l /etc/s6/openssh/log -U -u root -g root spawn openssh
   ```

6. Enable the service:
   ```bash
   ln -s /etc/s6-rc/databases/available/openssh /etc/s6-rc/databases/current/openssh
   s6-rc-db update
   ```

## Service Dependencies

s6-rc allows you to define dependencies between services. For example, to ensure networking is available before starting openssh:

```bash
# In the openssh database entry
#!/bin/sh
exec s6-rc -l /etc/s6/openssh/log \\
    -U \\
    -u root -g root \\
    -a "network" \\
    spawn openssh
```

This ensures that services in the "network" bundle are started before openssh.
EOF
    
    # Create config files
    cat > "${profile_dir}/config/base.conf" << 'EOF'
# NotLFS Base Profile Configuration
# =================================

# Build options
BUILD_OPTIMIZATION="-O2 -pipe"
STRIP_DEBUG="false"
KEEP_SOURCES="false"

# System options
HOSTNAME="notlfs-base"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"

# Network options
ENABLE_NETWORK="true"
NETWORK_INTERFACES="eth0"
USE_DHCP="true"
NAMESERVERS="8.8.8.8 8.8.4.4"

# Security options
ENABLE_HARDENING="true"
STACK_PROTECTOR="true"
FORTIFY_SOURCE="true"
RELRO="true"
ASLR="true"
PIE="true"

# Init system
INIT_SYSTEM="s6-rc"

# Package options
INSTALL_DOCS="true"
INSTALL_MAN_PAGES="true"
INSTALL_INFO_PAGES="true"

# User options
ROOT_PASSWORD="changeme"
CREATE_USER="false"
USER_NAME="user"
USER_GROUPS="wheel,audio,video,storage"
EOF
    
    # Create hooks
    cat > "${profile_dir}/hooks/pre-build.sh" << 'EOF'
#!/bin/bash
# Base Profile - Pre-Build Hook

set -e

echo "=== Base Profile: Pre-Build Hook ==="

# Set standard optimization
if [ -z "$OPTIMIZATION" ]; then
    export OPTIMIZATION="-O2 -pipe"
    echo "Set optimization: $OPTIMIZATION"
fi

# Enable documentation
if [ -z "$INSTALL_DOCS" ]; then
    export INSTALL_DOCS="true"
    echo "Documentation enabled"
fi

# Enable networking
export ENABLE_NETWORK="true"
echo "Networking enabled"

# Set hostname
export HOSTNAME="notlfs-base"

echo "=== Base Profile: Pre-Build Complete ==="
EOF
    chmod +x "${profile_dir}/hooks/pre-build.sh"
    
    cat > "${profile_dir}/hooks/post-install.sh" << 'EOF'
#!/bin/bash
# Base Profile - Post-Install Hook

set -e

echo "=== Base Profile: Post-Install Hook ==="

# Create /etc/issue
cat > ${LFS}/etc/issue << 'ISSUE'
NotLFS Base \r (\n)
Kernel \r on an \m
ISSUE

# Create /etc/motd
cat > ${LFS}/etc/motd << 'MOTD'
Welcome to NotLFS Base
A complete Linux system built from source

System information:
  Distribution: NotLFS Base
  Kernel:       \r
  Uptime:       \u
  Load:         \l

Type 'help' for available commands
MOTD

# Set hostname
echo "notlfs-base" > ${LFS}/etc/hostname

# Create shell profile
cat > ${LFS}/etc/profile << 'PROFILE'
# Base shell profile
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PS1='\u@\h:\w\$ '
export EDITOR=vim
export PAGER=less

# Add user binaries to PATH if they exist
if [ -d /usr/local/bin ]; then
    PATH="/usr/local/bin:$PATH"
fi
PROFILE

# Configure bash
cat > ${LFS}/etc/bashrc << 'BASHRC'
# Base bash configuration
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PS1='\u@\h:\w\$ '
export EDITOR=vim
export PAGER=less

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# History
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
BASHRC

# Create /etc/fstab
cat > ${LFS}/etc/fstab << 'FSTAB'
# Base fstab
proc    /proc   proc    defaults        0       0
sysfs   /sys    sysfs   defaults        0       0
devpts  /dev/pts devpts  gid=5,mode=620 0       0
tmpfs   /dev/shm tmpfs  defaults        0       0
FSTAB

# Setup networking
mkdir -p ${LFS}/etc/network
cat > ${LFS}/etc/network/interfaces << 'INTERFACES'
# Network interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
INTERFACES

# Setup resolv.conf
cat > ${LFS}/etc/resolv.conf << 'RESOLV'
nameserver 8.8.8.8
nameserver 8.8.4.4
RESOLV

# Setup s6-rc init system
if [ "$INIT_SYSTEM" = "s6-rc" ]; then
    echo "Configuring s6-rc init system..."
    
    # Create directory structure
    mkdir -p ${LFS}/etc/s6-rc/databases/available
    mkdir -p ${LFS}/etc/s6-rc/databases/current
    mkdir -p ${LFS}/etc/s6/current
    
    # Create s6-rc-init service
    mkdir -p ${LFS}/etc/s6/s6-rc-init
    cat > ${LFS}/etc/s6/s6-rc-init/run << 'RUN'
#!/bin/sh
exec s6-rc -l /etc/s6-rc/log -U -u root -g root init
RUN
    chmod +x ${LFS}/etc/s6/s6-rc-init/run
    
    # Create s6-svscan service
    mkdir -p ${LFS}/etc/s6/s6-svscan
    cat > ${LFS}/etc/s6/s6-svscan/run << 'RUN'
#!/bin/sh
exec s6-svscan /etc/s6/current
RUN
    chmod +x ${LFS}/etc/s6/s6-svscan/run
    
    # Create database entry for s6-rc-init
    cat > ${LFS}/etc/s6-rc/databases/available/s6-rc-init << 'DB'
#!/bin/sh
exec s6-rc -l /etc/s6/s6-rc-init/log spawn s6-rc-init
DB
    chmod +x ${LFS}/etc/s6-rc/databases/available/s6-rc-init
    
    # Enable s6-rc-init
    ln -sf /etc/s6-rc/databases/available/s6-rc-init ${LFS}/etc/s6-rc/databases/current/s6-rc-init
    
    # Create log directories
    mkdir -p ${LFS}/etc/s6/s6-rc-init/log
    mkdir -p ${LFS}/etc/s6/s6-svscan/log
    
    cat > ${LFS}/etc/s6/s6-rc-init/log/run << 'LOG'
#!/bin/sh
exec s6-log /var/log/s6-rc-init
LOG
    chmod +x ${LFS}/etc/s6/s6-rc-init/log/run
    
    cat > ${LFS}/etc/s6/s6-svscan/log/run << 'LOG'
#!/bin/sh
exec s6-log /var/log/s6-svscan
LOG
    chmod +x ${LFS}/etc/s6/s6-svscan/log/run
    
    # Create /run directory
    mkdir -p ${LFS}/run
    
    # Create inittab symlink
    ln -sf /bin/s6-rc-init ${LFS}/sbin/init
    
    echo "s6-rc init system configured"
fi

# Create var directories
mkdir -p ${LFS}/var/log
mkdir -p ${LFS}/var/cache
mkdir -p ${LFS}/var/lib
mkdir -p ${LFS}/var/run
mkdir -p ${LFS}/var/spool

# Create tmp directory
mkdir -p ${LFS}/tmp
chmod 1777 ${LFS}/tmp

# Create home directory
mkdir -p ${LFS}/home

# Create root home directory
mkdir -p ${LFS}/root
chmod 700 ${LFS}/root

# Setup timezone
if [ -f ${LFS}/usr/share/zoneinfo/UTC ]; then
    ln -sf /usr/share/zoneinfo/UTC ${LFS}/etc/localtime
    echo "UTC" > ${LFS}/etc/timezone
fi

# Setup locale
mkdir -p ${LFS}/etc/default
cat > ${LFS}/etc/default/locale << 'LOCALE'
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
LOCALE

echo "=== Base Profile: Post-Install Complete ==="
EOF
    chmod +x "${profile_dir}/hooks/post-install.sh"
    
    log_info "Base profile created successfully"
}

# =============================================================================
# PROFILE 3: DESKTOP (KDE PLASMA)
# =============================================================================
#
# The desktop profile provides a full desktop environment with KDE Plasma.
# It includes everything from the base profile plus graphical libraries,
# desktop environment, multimedia support, and productivity applications.
#
# Use case: Desktop workstations, development machines with GUI,
#           or systems requiring a full graphical environment
#
# Default init system: s6-rc (with display manager integration)
# Estimated build time: 6-12 hours
# Estimated disk space: 8-15 GB
#

create_desktop_profile() {
    local profile_name="desktop"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    
    log_section "Creating DESKTOP (KDE Plasma) Profile"
    create_profile_directory "$profile_name"
    
    # Create profile.xml
    cat > "${profile_dir}/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!--
    NotLFS Desktop Profile (KDE Plasma)
    ===================================
    Full desktop environment with KDE Plasma, multimedia support,
    and productivity applications.
-->
<profile name="desktop">
    <description>Full NotLFS desktop system with KDE Plasma, graphical applications, and multimedia support</description>
    <author>NotLFS Team</author>
    <version>1.0</version>
    
    <!-- Recommended init system -->
    <init_system>s6-rc</init_system>
    
    <!-- Supported init systems -->
    <supported_init_systems>
        <init>s6-rc</init>
        <init>systemd</init>
        <init>openrc</init>
        <init>runit</init>
    </supported_init_systems>
    
    <!-- Inherit from base profile -->
    <inherits>
        <profile>base</profile>
    </inherits>
    
    <!-- Package selections -->
    <packages>
        <!-- Include all base packages -->
        <include profile="base" />
        
        <!-- Desktop environment -->
        <include category="desktop" />
        
        <!-- KDE Plasma specific packages -->
        <package name="kf5-plasma" enabled="true" />
        <package name="kf5-plasma-desktop" enabled="true" />
        <package name="kf5-plasma-workspace" enabled="true" />
        <package name="kf5-kwin" enabled="true" />
        <package name="kf5-kded" enabled="true" />
        <package name="kf5-ksysguard" enabled="true" />
        <package name="kf5-kio" enabled="true" />
        <package name="kf5-kwidgetsaddons" enabled="true" />
        <package name="kf5-kconfigwidgets" enabled="true" />
        <package name="kf5-kcoreaddons" enabled="true" />
        <package name="kf5-kdbusaddons" enabled="true" />
        <package name="kf5-kguiaddons" enabled="true" />
        <package name="kf5-knotifications" enabled="true" />
        <package name="kf5-ktextwidgets" enabled="true" />
        <package name="kf5-solid" enabled="true" />
        
        <!-- KDE Applications -->
        <package name="kf5-kate" enabled="true" />
        <package name="kf5-konsole" enabled="true" />
        <package name="kf5-dolphin" enabled="true" />
        <package name="kf5-kcalc" enabled="true" />
        <package name="kf5-kcharselect" enabled="true" />
        <package name="kf5-kcolorchooser" enabled="true" />
        <package name="kf5-kdenlive" enabled="false" />
        <package name="kf5-kdf" enabled="true" />
        <package name="kf5-kgpg" enabled="true" />
        <package name="kf5-khelpcenter" enabled="true" />
        <package name="kf5-konqueror" enabled="false" />
        <package name="kf5-kruler" enabled="true" />
        <package name="kf5-ktimer" enabled="true" />
        <package name="kf5-kwrite" enabled="true" />
        <package name="kf5-okular" enabled="true" />
        <package name="kf5-partitionmanager" enabled="false" />
        
        <!-- Display manager -->
        <package name="sddm" enabled="true" />
        <package name="lightdm" enabled="false" />
        <package name="gdm" enabled="false" />
        
        <!-- Graphics stack -->
        <include category="graphics" />
        <package name="mesa" enabled="true" />
        <package name="mesa-demos" enabled="false" />
        <package name="libglvnd" enabled="true" />
        <package name="vulkan-icd-loader" enabled="true" />
        <package name="vulkan-headers" enabled="true" />
        
        <!-- X11 and Wayland -->
        <package name="xorg-server" enabled="true" />
        <package name="xorg-server-xwayland" enabled="true" />
        <package name="xorg-apps" enabled="true" />
        <package name="xorg-drivers" enabled="true" />
        <package name="xorg-fonts" enabled="true" />
        <package name="wayland" enabled="true" />
        <package name="weston" enabled="false" />
        <package name="plasma-wayland-session" enabled="true" />
        
        <!-- Input devices -->
        <package name="libinput" enabled="true" />
        <package name="xorg-x11-drv-evdev" enabled="true" />
        <package name="xorg-x11-drv-libinput" enabled="true" />
        <package name="xorg-x11-drv-mouse" enabled="true" />
        <package name="xorg-x11-drv-keyboard" enabled="true" />
        
        <!-- Audio -->
        <package name="pulseaudio" enabled="true" />
        <package name="pipewire" enabled="false" />
        <package name="alsa-lib" enabled="true" />
        <package name="alsa-utils" enabled="true" />
        <package name="alsa-plugins" enabled="true" />
        <package name="libao" enabled="true" />
        <package name="libsndfile" enabled="true" />
        
        <!-- Video -->
        <package name="ffmpeg" enabled="true" />
        <package name="mpv" enabled="true" />
        <package name="vlc" enabled="false" />
        <package name="gstreamer" enabled="true" />
        <package name="gst-plugins-base" enabled="true" />
        <package name="gst-plugins-good" enabled="true" />
        <package name="gst-plugins-bad" enabled="false" />
        <package name="gst-plugins-ugly" enabled="false" />
        <package name="gst-libav" enabled="false" />
        
        <!-- Fonts -->
        <package name="dejavu-fonts" enabled="true" />
        <package name="liberation-fonts" enabled="true" />
        <package name="gnu-free-fonts" enabled="true" />
        <package name="fontconfig" enabled="true" />
        <package name="freetype" enabled="true" />
        <package name="harfbuzz" enabled="true" />
        
        <!-- Themes and icons -->
        <package name="breeze" enabled="true" />
        <package name="breeze-icons" enabled="true" />
        <package name="oxygen" enabled="true" />
        <package name="oxygen-icons" enabled="true" />
        <package name="hicolor-icon-theme" enabled="true" />
        <package name="adwaita-icon-theme" enabled="true" />
        
        <!-- Productivity applications -->
        <package name="firefox" enabled="true" />
        <package name="thunderbird" enabled="false" />
        <package name="libreoffice" enabled="false" />
        <package name="calligra" enabled="false" />
        <package name="gimp" enabled="false" />
        <package name="inkscape" enabled="false" />
        <package name="blender" enabled="false" />
        
        <!-- Office and productivity -->
        <package name="abiuword" enabled="false" />
        <package name="gnumeric" enabled="false" />
        <package name="evince" enabled="true" />
        <package name="atril" enabled="false" />
        <package name="galculator" enabled="true" />
        
        <!-- File managers -->
        <package name="nautilus" enabled="false" />
        <package name="thunar" enabled="false" />
        <package name="pcmanfm" enabled="false" />
        
        <!-- Terminal emulators -->
        <package name="konsole" enabled="true" />
        <package name="yakuake" enabled="false" />
        <package name="xterm" enabled="true" />
        <package name="rxvt-unicode" enabled="false" />
        
        <!-- Utilities -->
        <package name="ark" enabled="true" />
        <package name="filelight" enabled="true" />
        <package name="gwenview" enabled="true" />
        <package name="kamoso" enabled="false" />
        <package name="kcachegrind" enabled="false" />
        <package name="kcalc" enabled="true" />
        <package name="kcharselect" enabled="true" />
        <package name="kcolorchooser" enabled="true" />
        <package name="kdenlive" enabled="false" />
        <package name="kdf" enabled="true" />
        <package name="kgpg" enabled="true" />
        <package name="khelpcenter" enabled="true" />
        
        <!-- Network utilities -->
        <package name="networkmanager" enabled="true" />
        <package name="network-manager-applet" enabled="true" />
        <package name="wpa_supplicant" enabled="true" />
        <package name="wireless_tools" enabled="true" />
        
        <!-- Bluetooth -->
        <package name="bluez" enabled="true" />
        <package name="blueman" enabled="false" />
        
        <!-- Printing -->
        <package name="cups" enabled="true" />
        <package name="hplip" enabled="false" />
        <package name="ghostscript" enabled="true" />
        
        <!-- Scanning -->
        <package name="sane" enabled="true" />
        <package name="xsane" enabled="true" />
        
        <!-- Multimedia codecs -->
        <package name="x264" enabled="true" />
        <package name="x265" enabled="false" />
        <package name="libvpx" enabled="true" />
        <package name="libtheora" enabled="true" />
        <package name="libvorbis" enabled="true" />
        <package name="libopus" enabled="true" />
        <package name="flac" enabled="true" />
        <package name="lame" enabled="true" />
        
        <!-- Screen and display -->
        <package name="xrandr" enabled="true" />
        <package name="xgamma" enabled="true" />
        <package name="xcalib" enabled="false" />
        <package name="redshift" enabled="false" />
        
        <!-- Screenshots -->
        <package name="ksnapshot" enabled="true" />
        <package name="spectacle" enabled="true" />
        
        <!-- Clipboard -->
        <package name="klipper" enabled="true" />
        
        <!-- Notifications -->
        <package name="notify-osd" enabled="false" />
        
        <!-- Power management -->
        <package name="upower" enabled="true" />
        <package name="powerdevil" enabled="true" />
        
        <!-- Polkit for administrative tasks -->
        <package name="polkit" enabled="true" />
        <package name="polkit-kde" enabled="true" />
        
        <!-- D-Bus for inter-process communication -->
        <package name="dbus" enabled="true" />
        
        <!-- UDISKS for storage management -->
        <package name="udisks2" enabled="true" />
        <package name="udiskie" enabled="false" />
        
        <!-- Elogind for session management -->
        <package name="elogind" enabled="true" />
    </packages>
    
    <!-- Feature flags -->
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
        <feature name="desktop">true</feature>
        <feature name="server">false</feature>
        <feature name="hardening">true</feature>
        <feature name="strip_debug">false</feature>
        <feature name="documents">true</feature>
        <feature name="gui">true</feature>
        <feature name="sound">true</feature>
        <feature name="video">true</feature>
        <feature name="multimedia">true</feature>
    </features>
    
    <!-- Desktop configuration -->
    <desktop>
        <environment>kde</environment>
        <display_manager>sddm</display_manager>
        <window_manager>kwin</window_manager>
        <compositor>kwin_compositor</compositor>
        <session_type>plasma</session_type>
        <wayland_support>true</wayland_support>
        <x11_support>true</x11_support>
    </desktop>
    
    <!-- Build configuration -->
    <build>
        <optimization>-O2 -pipe</optimization>
        <jobs>$(nproc)</jobs>
        <strip_debug>false</strip_debug>
        <keep_sources>false</keep_sources>
    </build>
    
    <!-- Security hardening -->
    <security>
        <stack_protector>true</stack_protector>
        <fortify_source>true</fortify_source>
        <relro>true</relro>
        <aslr>true</aslr>
        <pie>true</pie>
    </security>
    
    <!-- Network configuration -->
    <network>
        <hostname>notlfs-desktop</hostname>
        <domain>local</domain>
        <enable_dhcp>true</enable_dhcp>
        <nameservers>8.8.8.8 8.8.4.4</nameservers>
        <enable_wifi>true</enable_wifi>
        <enable_bluetooth>true</enable_bluetooth>
    </network>
    
    <!-- Hooks -->
    <hooks>
        <hook stage="pre-toolchain">
            echo "Building desktop profile - including GUI support"
        </hook>
        <hook stage="pre-build">
            # Check for required build dependencies
            assert_command Xvfb
            assert_command xauth
        </hook>
        <hook stage="post-system">
            echo "Configuring desktop environment..."
        </hook>
        <hook stage="post-install">
            echo "Setting up KDE Plasma desktop..."
        </hook>
    </hooks>
</profile>
EOF
    
    # Create packages.list
    cat > "${profile_dir}/packages.list" << 'EOF'
# NotLFS Desktop Profile (KDE Plasma) - Package List
# =================================================
# Full desktop environment with KDE Plasma

# Include all base packages
include base

# Graphics stack
mesa
libglvnd
vulkan-icd-loader
vulkan-headers
xorg-server
xorg-server-xwayland
xorg-apps
xorg-drivers
xorg-fonts
wayland
libinput
xorg-x11-drv-evdev
xorg-x11-drv-libinput
xorg-x11-drv-mouse
xorg-x11-drv-keyboard

# Audio
pulseaudio
alsa-lib
alsa-utils
alsa-plugins
libao
libsndfile

# Video and multimedia
ffmpeg
mpv
gstreamer
gst-plugins-base
gst-plugins-good

# Fonts
fontconfig
freetype
harfbuzz
dejavu-fonts
liberation-fonts
gnu-free-fonts
hicolor-icon-theme
adwaita-icon-theme

# KDE Plasma
kf5-plasma
kf5-plasma-desktop
kf5-plasma-workspace
kf5-kwin
kf5-kded
kf5-ksysguard
kf5-kio
kf5-kwidgetsaddons
kf5-kconfigwidgets
kf5-kcoreaddons
kf5-kdbusaddons
kf5-kguiaddons
kf5-knotifications
kf5-ktextwidgets
kf5-solid

# KDE Applications
kf5-kate
kf5-konsole
kf5-dolphin
kf5-kcalc
kf5-kcharselect
kf5-kcolorchooser
kf5-kdf
kf5-kgpg
kf5-khelpcenter
kf5-kruler
kf5-ktimer
kf5-kwrite
kf5-okular

# Display manager
sddm

# Themes
breeze
breeze-icons
oxygen
oxygen-icons

# Utilities
ark
filelight
gwenview
kamoso
kcalc
kcharselect
kcolorchooser
kdf
kgpg
khelpcenter
ksnapshot
spectacle
klipper

# Network
networkmanager
network-manager-applet
wpa_supplicant
wireless_tools
bluez

# Printing and scanning
cups
ghostscript
sane
xsane

# System services
dbus
elogind
udisks2
polkit
polkit-kde
upower
powerdevil

# Web browser
firefox

# PDF viewer
evince

# Calculator
galculator

# Codecs
x264
libvpx
libtheora
libvorbis
libopus
flac
lame
EOF
    
    # Create README.md
    cat > "${profile_dir}/README.md" << 'EOF'
# NotLFS Desktop Profile (KDE Plasma)

## Overview

The **Desktop** profile provides a full desktop environment with **KDE Plasma**, including graphical applications, multimedia support, and productivity tools. It builds upon the base profile and adds everything needed for a complete desktop experience.

## Features

- ✅ Full KDE Plasma desktop environment
- ✅ Complete graphics stack (X11 and Wayland support)
- ✅ Audio support (PulseAudio + ALSA)
- ✅ Video playback (ffmpeg, mpv, gstreamer)
- ✅ Multimedia codecs (x264, libvpx, libvorbis, etc.)
- ✅ Fonts and themes (Breeze, Oxygen, DejaVu, etc.)
- ✅ Productivity applications (Kate, Konsole, Dolphin, etc.)
- ✅ Network management (NetworkManager)
- ✅ Bluetooth support
- ✅ Printing and scanning (CUPS, SANE)
- ✅ Power management
- ✅ Display manager (SDDM)
- ✅ Firefox web browser

## Use Cases

- Desktop workstations
- Development machines with GUI
- General-purpose desktop computers
- Systems requiring a full graphical environment
- KDE Plasma enthusiasts

## Default Init System

**s6-rc** - A dependency-based service manager that works well with desktop environments.

Alternative supported init systems:
- **systemd** - Recommended for full desktop integration (logind, etc.)
- **openrc** - Good alternative with desktop support
- **runit** - Lightweight option

> **Note**: While s6-rc is the default, **systemd** is recommended for the best desktop experience due to its built-in support for:
> - Session management (logind)
> - Power management
> - Device management (udev)
> - D-Bus activation

To use systemd instead:
```bash
./notlfs.sh -p desktop -i systemd
```

## Package Selection

### Included Categories
- All packages from the **base** profile
- `desktop` - Desktop environment packages
- `graphics` - Graphics stack (Mesa, Xorg, Wayland)

### KDE Plasma Components
- **Plasma Desktop**: kf5-plasma, kf5-plasma-desktop, kf5-plasma-workspace
- **Window Manager**: kf5-kwin (with Wayland and X11 support)
- **System Services**: kf5-kded, kf5-ksysguard
- **File Management**: kf5-kio, kf5-dolphin
- **Utilities**: kf5-kwidgetsaddons, kf5-kconfigwidgets, kf5-kcoreaddons

### KDE Applications
- **Editor**: kf5-kate, kf5-kwrite
- **Terminal**: kf5-konsole
- **File Manager**: kf5-dolphin
- **System Monitor**: kf5-ksysguard
- **Calculator**: kf5-kcalc
- **Help Center**: kf5-khelpcenter
- **Document Viewer**: kf5-okular
- **Archiving**: ark
- **Disk Usage**: filelight
- **Image Viewer**: gwenview
- **Disk Free**: kf5-kdf
- **GPG**: kf5-kgpg

### Graphics Stack
- **Mesa**: Open-source graphics drivers
- **Xorg Server**: X11 display server with Wayland support
- **Libinput**: Input device handling
- **Wayland**: Modern display protocol

### Audio
- **PulseAudio**: Sound server
- **ALSA**: Advanced Linux Sound Architecture
- **Codecs**: Various audio codecs (FLAC, LAME, libvorbis, etc.)

### Video
- **ffmpeg**: Video encoding/decoding
- **mpv**: Video player
- **gstreamer**: Multimedia framework

### Themes and Fonts
- **Breeze**: Default KDE theme and icons
- **Oxygen**: Alternative KDE theme and icons
- **DejaVu Fonts**: High-quality fonts
- **Liberation Fonts**: Metric-compatible fonts
- **GNU Free Fonts**: Free fonts

### System Services
- **SDDM**: Simple Desktop Display Manager
- **NetworkManager**: Network configuration
- **D-Bus**: Inter-process communication
- **elogind**: Session management (for non-systemd)
- **udisks2**: Storage management
- **Polkit**: Authorization framework
- **UPower**: Power management
- **CUPS**: Printing system
- **SANE**: Scanner support

## Customization

### Adding More Applications

To add additional applications to the desktop profile:

```xml
<profile name="my-desktop">
    <include profile="desktop" />
    <packages>
        <!-- Add LibreOffice -->
        <package name="libreoffice" enabled="true" />
        
        <!-- Add GIMP -->
        <package name="gimp" enabled="true" />
        
        <!-- Add VLC -->
        <package name="vlc" enabled="true" />
    </packages>
</profile>
```

### Changing the Desktop Environment

To use a different desktop environment, create a custom profile:

```xml
<profile name="gnome-desktop">
    <include profile="base" />
    <packages>
        <include category="graphics" />
        <package name="gnome-shell" />
        <package name="gnome-session" />
        <package name="gnome-control-center" />
        <package name="nautilus" />
        <package name="gedit" />
        <package name="gnome-terminal" />
        <package name="gdm" />
    </packages>
    <desktop>
        <environment>gnome</environment>
        <display_manager>gdm</display_manager>
    </desktop>
</profile>
```

### Disabling Features

To create a lighter desktop profile without certain features:

```xml
<profile name="light-desktop">
    <include profile="desktop" />
    <packages>
        <!-- Disable heavy applications -->
        <package name="libreoffice" enabled="false" />
        <package name="gimp" enabled="false" />
        <package name="blender" enabled="false" />
        
        <!-- Disable multimedia codecs for size -->
        <package name="gst-plugins-bad" enabled="false" />
        <package name="gst-plugins-ugly" enabled="false" />
    </packages>
</profile>
```

## Build Configuration

```bash
# Build with desktop profile (takes 6-12 hours)
./notlfs.sh -p desktop

# Build with systemd for best desktop integration
./notlfs.sh -p desktop -i systemd

# Build with more parallel jobs
./notlfs.sh -p desktop --jobs 8

# Build in auto mode (unattended - not recommended for desktop)
./notlfs.sh -p desktop -m auto

# Build in interactive mode (recommended)
./notlfs.sh -p desktop -m interactive
```

## Build Dependencies

Building the desktop profile requires additional build dependencies on the host system:

- **X11 development libraries** (libx11-dev, libxext-dev, etc.)
- **Wayland development libraries** (libwayland-dev)
- **Mesa development libraries** (libgl1-mesa-dev, libgles2-mesa-dev)
- **Qt5 development libraries** (qt5-default, qtbase5-dev, etc.)
- **KDE Frameworks 5 development libraries**

On Debian/Ubuntu:
```bash
sudo apt-get install build-essential cmake git \
    libx11-dev libxext-dev libxcb1-dev libxrender-dev \
    libwayland-dev libegl1-mesa-dev libgles2-mesa-dev \
    qt5-default qtbase5-dev qtdeclarative5-dev \
    extra-cmake-modules
```

## Post-Installation

After installation, you'll have a complete KDE Plasma desktop environment.

### First Boot

1. The system will boot to the **SDDM** display manager
2. Log in with the root account or a user account
3. The KDE Plasma desktop will start

### Creating a User Account

It's recommended to create a regular user account for daily use:

```bash
# Add a user (from root shell or chroot)
useradd -m -G wheel,audio,video,storage,kvm myuser
passwd myuser

# Add to sudoers (if using sudo)
echo "myuser ALL=(ALL) ALL" >> /etc/sudoers
```

### Configuring SDDM

To customize the SDDM display manager:

```bash
# Edit the configuration file
nano /etc/sddm.conf

# Or use the KDE configuration tool
systemsettings5
```

### Switching Between X11 and Wayland

At the SDDM login screen:
1. Click the session type button (usually in the bottom-left corner)
2. Select "Plasma (X11)" or "Plasma (Wayland)"
3. Log in

### Audio Configuration

To test audio:
```bash
aplay /usr/share/sounds/alsa/Front_Center.wav
```

To configure audio devices:
```bash
alsamixer
```

### Video Playback

To test video playback:
```bash
mpv /path/to/video.mp4
```

### Network Configuration

NetworkManager should start automatically. Use the KDE Plasma network applet to:
- Connect to Wi-Fi networks
- Configure wired connections
- Manage VPN connections

### Bluetooth

To enable Bluetooth:
```bash
# Start the Bluetooth service
rc-service bluetooth start  # For openrc
systemctl start bluetooth  # For systemd

# Or manually
bluetoothd &
```

Then use the KDE Plasma Bluetooth applet to pair devices.

### Printing

To add a printer:
1. Open System Settings
2. Go to "Printers"
3. Click "Add Printer"
4. Follow the prompts to add your printer

### Scanning

To use a scanner:
```bash
simple-scan
# or
xsane
```

## Service Management

### With s6-rc (default)

```bash
# List all services
s6-rc-db list

# Check service status
s6-rc -a list

# Start a service
s6-rc -u change <service>

# Stop a service
s6-rc -d change <service>
```

### With systemd

```bash
# List all services
systemctl list-units --type=service

# Start a service
systemctl start <service>

# Enable a service at boot
systemctl enable <service>

# Stop a service
systemctl stop <service>
```

## Tips and Tricks

### Enable Compositing

KWin provides desktop compositing (visual effects):
1. Open System Settings
2. Go to "Display and Monitor" > "Compositor"
3. Enable "Allow applications to block compositing"
4. Select your preferred compositing mode

### Enable Desktop Effects

1. Open System Settings
2. Go to "Workspace Behavior" > "Desktop Effects"
3. Enable your preferred effects

### Customize Plasma Theme

1. Open System Settings
2. Go to "Appearance" > "Plasma Style"
3. Select a theme (Breeze, Oxygen, etc.)

### Install Additional Plasma Themes

Download themes from [store.kde.org](https://store.kde.org) and install them using:
```bash
# For global installation
cp -r theme-name /usr/share/plasma/desktoptheme/

# For user installation
cp -r theme-name ~/.local/share/plasma/desktoptheme/
```

## Performance Considerations

- The desktop profile has a **large build time** (6-12 hours depending on hardware)
- It requires **significant disk space** (8-15 GB)
- Building KDE Plasma requires **at least 8 GB of RAM** (16 GB recommended)
- Consider using **tmpfs for /tmp** to speed up builds:
  ```bash
  mount -t tmpfs -o size=8G tmpfs /tmp
  ```

## Troubleshooting

### Xorg Server Fails to Start

Check the Xorg log:
```bash
cat /var/log/Xorg.0.log | grep -i error
```

Common issues:
- Missing graphics drivers
- Incorrect display configuration
- Permission issues

### No Sound

Check ALSA:
```bash
alsamixer
```

Check PulseAudio:
```bash
pulseaudio --check && echo "PulseAudio running" || echo "PulseAudio not running"
pactl list sinks
```

### KDE Plasma Crashes

Check the log:
```bash
cat ~/.xsession-errors | grep -i error
```

Try resetting the configuration:
```bash
mv ~/.config ~/.config.bak
mv ~/.local ~/.local.bak
```

## Notes

- This profile includes **Firefox** as the default web browser. You can replace it with Chromium or another browser.
- **LibreOffice** is not included by default due to its size. Add it if needed.
- **GIMP** and **Blender** are not included by default. Add them for graphics work.
- The profile supports both **X11** and **Wayland**. Wayland is the future but X11 has better compatibility.
- For **NVIDIA** graphics, you'll need to install the proprietary drivers separately.
- For **AMD** graphics, the open-source drivers (radeon, amdgpu) are included in Mesa.
- For **Intel** graphics, the open-source drivers are included in Mesa.
EOF
    
    # Create service definitions for s6-rc with desktop support
    mkdir -p "${profile_dir}/services/s6-rc"
    cat > "${profile_dir}/services/s6-rc/README.md" << 'EOF'
# Desktop Profile - s6-rc Service Definitions

This directory contains service definitions for the s6-rc init system when using the desktop profile with KDE Plasma.

## Default Services

The desktop profile includes the following services:

1. **s6-rc-init** - s6-rc initialization
2. **s6-svscan** - s6 service supervisor
3. **dbus** - D-Bus message bus system
4. **elogind** - Session management (for non-systemd)
5. **udisks2** - Storage management
6. **upower** - Power management
7. **polkit** - Authorization framework
8. **networkmanager** - Network management
9. **sddm** - Display manager
10. **pulseaudio** - Sound server (per-user)
11. **cups** - Printing system
12. **bluetoothd** - Bluetooth daemon
13. **cronie** - Cron daemon

## Service Dependencies

The desktop profile has complex service dependencies. Here's the dependency tree:

```
s6-rc-init
├── dbus
│   └── polkit
├── elogind
│   ├── upower
│   └── udisks2
├── networkmanager
├── sddm
│   ├── dbus
│   ├── elogind
│   └── xorg-server
├── cups
└── bluetoothd
```

## Creating Service Definitions

### Example: SDDM Display Manager

1. Create the service directory:
   ```bash
   mkdir -p /etc/s6/sddm
   ```

2. Create the run script (`/etc/s6/sddm/run`):
   ```bash
   #!/bin/sh
   exec /usr/bin/sddm
   ```

3. Create the finish script (`/etc/s6/sddm/finish`):
   ```bash
   #!/bin/sh
   exec s6-notifywhenup "$1"
   ```

4. Create the log directory:
   ```bash
   mkdir -p /etc/s6/sddm/log
   cat > /etc/s6/sddm/log/run << 'LOG'
   #!/bin/sh
   exec s6-log /var/log/sddm
   LOG
   chmod +x /etc/s6/sddm/log/run
   ```

5. Create the database entry (`/etc/s6-rc/databases/available/sddm`):
   ```bash
   #!/bin/sh
   exec s6-rc -l /etc/s6/sddm/log \\
       -U \\
       -u root -g root \\
       -a "dbus,elogind,networkmanager" \\
       -b "xorg-server" \\
       spawn sddm
   ```

   This ensures that:
   - dbus, elogind, and networkmanager are started before sddm
   - xorg-server is started as a bundle (parallel with sddm)

6. Enable the service:
   ```bash
   ln -s /etc/s6-rc/databases/available/sddm /etc/s6-rc/databases/current/sddm
   s6-rc-db update
   ```

### Example: D-Bus

D-Bus is required for many desktop applications:

1. Create the service directory:
   ```bash
   mkdir -p /etc/s6/dbus
   ```

2. Create the run script:
   ```bash
   #!/bin/sh
   exec /usr/bin/dbus-daemon --system --nopidfile
   ```

3. Create the database entry:
   ```bash
   #!/bin/sh
   exec s6-rc -l /etc/s6/dbus/log \\
       -U \\
       -u dbus -g dbus \\
       spawn dbus
   ```

### Example: NetworkManager

NetworkManager provides network connectivity:

1. Create the service directory:
   ```bash
   mkdir -p /etc/s6/networkmanager
   ```

2. Create the run script:
   ```bash
   #!/bin/sh
   exec /usr/bin/NetworkManager --daemon
   ```

3. Create the database entry:
   ```bash
   #!/bin/sh
   exec s6-rc -l /etc/s6/networkmanager/log \\
       -U \\
       -u root -g root \\
       -a "dbus" \\
       spawn networkmanager
   ```

## User Services

Some services (like PulseAudio) are per-user services. These are managed differently:

### PulseAudio (Per-User)

PulseAudio is typically started per-user, not as a system service. However, you can create a system-wide instance:

1. Create the service directory:
   ```bash
   mkdir -p /etc/s6/pulseaudio
   ```

2. Create the run script:
   ```bash
   #!/bin/sh
   exec /usr/bin/pulseaudio --system --daemonize --exit-idle-time=-1
   ```

3. Create the database entry:
   ```bash
   #!/bin/sh
   exec s6-rc -l /etc/s6/pulseaudio/log \\
       -U \\
       -u pulse -g pulse \\
       -a "dbus,elogind" \\
       spawn pulseaudio
   ```

## Desktop-Specific Services

### Polkit

Polkit provides authorization for administrative tasks:

1. Create the service directory:
   ```bash
   mkdir -p /etc/s6/polkit
   ```

2. Create the run script:
   ```bash
   #!/bin/sh
   exec /usr/lib/polkit-1/polkitd
   ```

3. Create the database entry:
   ```bash
   #!/bin/sh
   exec s6-rc -l /etc/s6/polkit/log \\
       -U \\
       -u polkitd -g polkitd \\
       -a "dbus" \\
       spawn polkit
   ```

### elogind

elogind provides session management (for non-systemd systems):

1. Create the service directory:
   ```bash
   mkdir -p /etc/s6/elogind
   ```

2. Create the run script:
   ```bash
   #!/bin/sh
   exec /usr/bin/elogind
   ```

3. Create the database entry:
   ```bash
   #!/bin/sh
   exec s6-rc -l /etc/s6/elogind/log \\
       -U \\
       -u root -g root \\
       -a "dbus" \\
       spawn elogind
   ```

### UDisks2

UDisks2 provides storage management:

1. Create the service directory:
   ```bash
   mkdir -p /etc/s6/udisks2
   ```

2. Create the run script:
   ```bash
   #!/bin/sh
   exec /usr/lib/udisks2/udisksd
   ```

3. Create the database entry:
   ```bash
   #!/bin/sh
   exec s6-rc -l /etc/s6/udisks2/log \\
       -U \\
       -u root -g root \\
       -a "dbus,elogind" \\
       spawn udisks2
   ```

## Initial Service Setup

After installation, you need to enable the required services:

```bash
# Enable all desktop services
for service in dbus elogind udisks2 upower polkit networkmanager cups bluetoothd sddm; do
    ln -sf /etc/s6-rc/databases/available/${service} /etc/s6-rc/databases/current/${service}
done

# Update the database
s6-rc-db update

# Start all services
s6-rc -u change all
```

## Using systemd Instead

If you choose to use systemd instead of s6-rc, the service management is much simpler:

```bash
# Enable services
systemctl enable dbus
systemctl enable elogind
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable cups
systemctl enable bluetooth

# Start services
systemctl start dbus
systemctl start NetworkManager
systemctl start sddm
```

systemd automatically handles all dependencies between services.
EOF
    
    # Create config files
    cat > "${profile_dir}/config/desktop.conf" << 'EOF'
# NotLFS Desktop Profile (KDE Plasma) Configuration
# ==================================================

# Build options
BUILD_OPTIMIZATION="-O2 -pipe"
STRIP_DEBUG="false"
KEEP_SOURCES="false"

# System options
HOSTNAME="notlfs-desktop"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"

# Network options
ENABLE_NETWORK="true"
NETWORK_INTERFACES="eth0 wlan0"
USE_DHCP="true"
NAMESERVERS="8.8.8.8 8.8.4.4"
ENABLE_WIFI="true"
ENABLE_BLUETOOTH="true"

# Security options
ENABLE_HARDENING="true"
STACK_PROTECTOR="true"
FORTIFY_SOURCE="true"
RELRO="true"
ASLR="true"
PIE="true"

# Init system
INIT_SYSTEM="s6-rc"

# Desktop options
DESKTOP_ENVIRONMENT="kde"
DISPLAY_MANAGER="sddm"
WINDOW_MANAGER="kwin"
ENABLE_WAYLAND="true"
ENABLE_X11="true"

# Package options
INSTALL_DOCS="true"
INSTALL_MAN_PAGES="true"
INSTALL_GUI="true"
INSTALL_MULTIMEDIA="true"

# User options
ROOT_PASSWORD="changeme"
CREATE_USER="true"
USER_NAME="user"
USER_GROUPS="wheel,audio,video,storage,kvm,input,render"
USER_PASSWORD="changeme"

# Graphics options
GRAPHICS_DRIVER="auto"  # auto, intel, amd, nvidia, nouveau
OPENGL_ES="true"
VULKAN="true"

# Audio options
AUDIO_SYSTEM="pulseaudio"  # pulseaudio, pipewire, alsa
ENABLE_SOUND="true"

# Video options
VIDEO_PLAYBACK="true"
VIDEO_ENCODING="true"

# Font options
INSTALL_FONTS="true"
FONTS="dejavu,liberation,gnu-free"

# KDE options
KDE_THEME="breeze"
KDE_ICONS="breeze"
KDE_COLOR_SCHEME="breeze"
KDE_PLASMA_STYLE="breeze"
KDE_WINDOW_DECORATIONS="breeze"
EOF
    
    # Create hooks
    cat > "${profile_dir}/hooks/pre-build.sh" << 'EOF'
#!/bin/bash
# Desktop Profile - Pre-Build Hook

set -e

echo "=== Desktop Profile (KDE Plasma): Pre-Build Hook ==="

# Set standard optimization
if [ -z "$OPTIMIZATION" ]; then
    export OPTIMIZATION="-O2 -pipe"
    echo "Set optimization: $OPTIMIZATION"
fi

# Enable GUI support
export ENABLE_GUI="true"
echo "GUI support enabled"

# Enable multimedia support
export ENABLE_MULTIMEDIA="true"
echo "Multimedia support enabled"

# Enable desktop features
export ENABLE_DESKTOP="true"
echo "Desktop features enabled"

# Set desktop environment
export DESKTOP_ENVIRONMENT="kde"
echo "Desktop environment: $DESKTOP_ENVIRONMENT"

# Set display manager
export DISPLAY_MANAGER="sddm"
echo "Display manager: $DISPLAY_MANAGER"

# Set hostname
export HOSTNAME="notlfs-desktop"

# Check for build dependencies
echo "Checking build dependencies..."

# Check for X11 development libraries
if ! command -v Xvfb &> /dev/null; then
    log_warn "Xvfb not found. GUI applications may not build correctly."
    log_warn "Install Xvfb for headless testing: sudo apt-get install xvfb"
fi

if ! command -v xauth &> /dev/null; then
    log_warn "xauth not found. X11 authentication may not work."
    log_warn "Install xauth: sudo apt-get install xauth"
fi

# Check for Qt5
if ! pkg-config --exists Qt5Core &> /dev/null; then
    log_warn "Qt5 development libraries not found."
    log_warn "KDE Plasma requires Qt5. Install: sudo apt-get install qt5-default qtbase5-dev"
fi

# Check for KF5
if ! pkg-config --exists KF5CoreAddons &> /dev/null; then
    log_warn "KDE Frameworks 5 not found."
    log_warn "KDE Plasma requires KF5. Install: sudo apt-get install kf5"
fi

echo "=== Desktop Profile: Pre-Build Complete ==="
EOF
    chmod +x "${profile_dir}/hooks/pre-build.sh"
    
    cat > "${profile_dir}/hooks/post-install.sh" << 'EOF'
#!/bin/bash
# Desktop Profile - Post-Install Hook

set -e

echo "=== Desktop Profile (KDE Plasma): Post-Install Hook ==="

# Create /etc/issue
cat > ${LFS}/etc/issue << 'ISSUE'
NotLFS Desktop (KDE Plasma) \r (\n)
Kernel \r on an \m
ISSUE

# Create /etc/motd
cat > ${LFS}/etc/motd << 'MOTD'
Welcome to NotLFS Desktop with KDE Plasma
A complete Linux desktop environment built from source

System information:
  Distribution: NotLFS Desktop (KDE Plasma)
  Kernel:       \r
  Uptime:       \u
  Load:         \l

To start the desktop environment:
  Start the display manager: systemctl start sddm
  Or manually: startx

Type 'help' for available commands
MOTD

# Set hostname
echo "notlfs-desktop" > ${LFS}/etc/hostname

# Create shell profile
cat > ${LFS}/etc/profile << 'PROFILE'
# Desktop shell profile
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PS1='\u@\h:\w\$ '
export EDITOR=kate
export PAGER=less

# Add user binaries to PATH
if [ -d /usr/local/bin ]; then
    PATH="/usr/local/bin:$PATH"
fi

# X11 environment
if [ -d /usr/X11R6/bin ]; then
    PATH="/usr/X11R6/bin:$PATH"
fi
export DISPLAY=:0
export XAUTHORITY=/home/$(whoami)/.Xauthority

# Qt5 environment
export QT_QPA_PLATFORM=xcb
PROFILE

# Configure bash
cat > ${LFS}/etc/bashrc << 'BASHRC'
# Desktop bash configuration
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PS1='\u@\h:\w\$ '
export EDITOR=kate
export PAGER=less

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias startplasma='startplasma-x11'
alias startwayland='startplasma-wayland'

# History
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
BASHRC

# Create /etc/fstab
cat > ${LFS}/etc/fstab << 'FSTAB'
# Desktop fstab
proc    /proc   proc    defaults        0       0
sysfs   /sys    sysfs   defaults        0       0
devpts  /dev/pts devpts  gid=5,mode=620 0       0
tmpfs   /dev/shm tmpfs  defaults        0       0
FSTAB

# Setup networking
mkdir -p ${LFS}/etc/network
cat > ${LFS}/etc/network/interfaces << 'INTERFACES'
# Network interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

auto wlan0
iface wlan0 inet dhcp
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
INTERFACES

# Setup resolv.conf
cat > ${LFS}/etc/resolv.conf << 'RESOLV'
nameserver 8.8.8.8
nameserver 8.8.4.4
RESOLV

# Setup s6-rc init system with desktop support
if [ "$INIT_SYSTEM" = "s6-rc" ]; then
    echo "Configuring s6-rc init system for desktop..."
    
    # Create directory structure
    mkdir -p ${LFS}/etc/s6-rc/databases/available
    mkdir -p ${LFS}/etc/s6-rc/databases/current
    mkdir -p ${LFS}/etc/s6/current
    
    # Create essential services
    local services=("dbus" "elogind" "udisks2" "upower" "polkit" "networkmanager" "cups" "bluetoothd" "sddm")
    
    for service in "${services[@]}"; do
        mkdir -p ${LFS}/etc/s6/${service}
        mkdir -p ${LFS}/etc/s6/${service}/log
        
        # Create run script
        cat > ${LFS}/etc/s6/${service}/run << RUN
#!/bin/sh
exec /usr/bin/${service} --daemon 2>/dev/null || exec /usr/sbin/${service} 2>/dev/null || echo "Service ${service} not found"
RUN
        chmod +x ${LFS}/etc/s6/${service}/run
        
        # Create log script
        cat > ${LFS}/etc/s6/${service}/log/run << LOG
#!/bin/sh
exec s6-log /var/log/${service}
LOG
        chmod +x ${LFS}/etc/s6/${service}/log/run
        
        # Create database entry
        cat > ${LFS}/etc/s6-rc/databases/available/${service} << DB
#!/bin/sh
exec s6-rc -l /etc/s6/${service}/log -U -u root -g root spawn ${service}
DB
        chmod +x ${LFS}/etc/s6-rc/databases/available/${service}
        
        # Enable service
        ln -sf /etc/s6-rc/databases/available/${service} ${LFS}/etc/s6-rc/databases/current/${service}
    done
    
    # Create s6-rc-init service
    mkdir -p ${LFS}/etc/s6/s6-rc-init
    cat > ${LFS}/etc/s6/s6-rc-init/run << 'RUN'
#!/bin/sh
exec s6-rc -l /etc/s6/s6-rc-init/log -U -u root -g root init
RUN
    chmod +x ${LFS}/etc/s6/s6-rc-init/run
    
    mkdir -p ${LFS}/etc/s6/s6-rc-init/log
    cat > ${LFS}/etc/s6/s6-rc-init/log/run << 'LOG'
#!/bin/sh
exec s6-log /var/log/s6-rc-init
LOG
    chmod +x ${LFS}/etc/s6/s6-rc-init/log/run
    
    cat > ${LFS}/etc/s6-rc/databases/available/s6-rc-init << 'DB'
#!/bin/sh
exec s6-rc -l /etc/s6/s6-rc-init/log spawn s6-rc-init
DB
    chmod +x ${LFS}/etc/s6-rc/databases/available/s6-rc-init
    ln -sf /etc/s6-rc/databases/available/s6-rc-init ${LFS}/etc/s6-rc/databases/current/s6-rc-init
    
    # Create s6-svscan service
    mkdir -p ${LFS}/etc/s6/s6-svscan
    cat > ${LFS}/etc/s6/s6-svscan/run << 'RUN'
#!/bin/sh
exec s6-svscan /etc/s6/current
RUN
    chmod +x ${LFS}/etc/s6/s6-svscan/run
    
    mkdir -p ${LFS}/etc/s6/s6-svscan/log
    cat > ${LFS}/etc/s6/s6-svscan/log/run << 'LOG'
#!/bin/sh
exec s6-log /var/log/s6-svscan
LOG
    chmod +x ${LFS}/etc/s6/s6-svscan/log/run
    
    # Link to current
    ln -sf /etc/s6/s6-rc-init ${LFS}/etc/s6/current/s6-rc-init
    ln -sf /etc/s6/s6-svscan ${LFS}/etc/s6/current/s6-svscan
    
    # Create /run directory
    mkdir -p ${LFS}/run
    
    # Create inittab symlink
    ln -sf /bin/s6-rc-init ${LFS}/sbin/init
    
    echo "s6-rc init system configured for desktop"
fi

# Create var directories
mkdir -p ${LFS}/var/log
mkdir -p ${LFS}/var/cache
mkdir -p ${LFS}/var/lib
mkdir -p ${LFS}/var/run
mkdir -p ${LFS}/var/spool

# Create tmp directory
mkdir -p ${LFS}/tmp
chmod 1777 ${LFS}/tmp

# Create home directory
mkdir -p ${LFS}/home

# Create root home directory
mkdir -p ${LFS}/root
chmod 700 ${LFS}/root

# Setup timezone
if [ -f ${LFS}/usr/share/zoneinfo/UTC ]; then
    ln -sf /usr/share/zoneinfo/UTC ${LFS}/etc/localtime
    echo "UTC" > ${LFS}/etc/timezone
fi

# Setup locale
mkdir -p ${LFS}/etc/default
cat > ${LFS}/etc/default/locale << 'LOCALE'
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
LOCALE

# Setup X11
mkdir -p ${LFS}/etc/X11
cat > ${LFS}/etc/X11/xorg.conf.d/00-keyboard.conf << 'XORG'
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us"
    Option "XkbModel" "pc105"
EndSection
XORG

# Setup SDDM configuration
mkdir -p ${LFS}/etc/sddm.conf.d
cat > ${LFS}/etc/sddm.conf.d/autologin.conf << 'SDDM'
[Autologin]
User=root
Session=plasma.desktop
SDDM

# Setup KDE Plasma defaults
mkdir -p ${LFS}/etc/xdg
mkdir -p ${LFS}/etc/xdg/kdeglobals
cat > ${LFS}/etc/xdg/kdeglobals << 'KDE'
[General]
Name=NotLFS
[KDE]
SingleClick=false

[General]
ColorSchemePath=breeze
IconThemePath=breeze
CursorTheme=breeze_cursors
FontPath=DejaVu Sans,10,-1,5,50,0,0,0,0,0
FixedFont=DejaVu Sans Mono,10,-1,5,50,0,0,0,0,0
ToolBarFont=DejaVu Sans,10,-1,5,50,0,0,0,0,0
MenuFont=DejaVu Sans,10,-1,5,50,0,0,0,0,0
WindowTitleFont=DejaVu Sans,10,-1,5,75,0,0,0,0,0
TaskbarFont=DejaVu Sans,10,-1,5,50,0,0,0,0,0
ActiveFont=DejaVu Sans,10,-1,5,75,0,0,0,0,0
KDE

# Setup PulseAudio defaults
mkdir -p ${LFS}/etc/pulse
cat > ${LFS}/etc/pulse/daemon.conf << 'PULSE'
; Allow high-resolution audio
high-priority = yes
nice-level = -11
realtime-scheduling = yes
realtime-priority = 50
resample-method = speex-float-1
default-fragments = 5
default-fragment-size-msec = 2
PULSE

# Setup ALSA defaults
mkdir -p ${LFS}/etc/asound.conf
cat > ${LFS}/etc/asound.conf << 'ALSA'
defaults.pcm.card 0
defaults.ctl.card 0
ALSA

# Create user account
echo "Creating user account..."
if [ "$CREATE_USER" = "true" ]; then
    USERNAME="${USER_NAME:-user}"
    USER_GROUPS="${USER_GROUPS:-wheel,audio,video,storage,kvm,input,render}"
    
    # Create groups
    for group in $(echo "$USER_GROUPS" | tr ',' '\n'); do
        grep -q "^${group}:" ${LFS}/etc/group 2>/dev/null || echo "${group}:::" >> ${LFS}/etc/group
    done
    
    # Create user
    if ! grep -q "^${USERNAME}:" ${LFS}/etc/passwd 2>/dev/null; then
        echo "${USERNAME}:x:1000:1000::/home/${USERNAME}:/bin/bash" >> ${LFS}/etc/passwd
        echo "${USERNAME}:x:1000:" >> ${LFS}/etc/shadow
        echo "${USERNAME}::1000:" >> ${LFS}/etc/group
        
        # Add user to groups
        for group in $(echo "$USER_GROUPS" | tr ',' '\n'); do
            if [ "$group" != "wheel" ]; then
                echo "${USERNAME}::1000:${group}" >> ${LFS}/etc/group
            fi
        done
        
        # Add to wheel group (for sudo)
        echo "${USERNAME}::1000:wheel" >> ${LFS}/etc/group
        
        # Create home directory
        mkdir -p ${LFS}/home/${USERNAME}
        chown 1000:1000 ${LFS}/home/${USERNAME}
        chmod 700 ${LFS}/home/${USERNAME}
        
        # Create user profile
        mkdir -p ${LFS}/home/${USERNAME}/.config
        mkdir -p ${LFS}/home/${USERNAME}/.local
        mkdir -p ${LFS}/home/${USERNAME}/.cache
        mkdir -p ${LFS}/home/${USERNAME}/Desktop
        mkdir -p ${LFS}/home/${USERNAME}/Documents
        mkdir -p ${LFS}/home/${USERNAME}/Downloads
        mkdir -p ${LFS}/home/${USERNAME}/Music
        mkdir -p ${LFS}/home/${USERNAME}/Pictures
        mkdir -p ${LFS}/home/${USERNAME}/Videos
        
        chown -R 1000:1000 ${LFS}/home/${USERNAME}
        
        # Set user password
        echo "${USER_NAME}:${USER_PASSWORD:-changeme}" | chpasswd -R ${LFS}
        
        echo "User ${USERNAME} created"
    fi
fi

# Setup sudoers
cat > ${LFS}/etc/sudoers << 'SUDO'
# /etc/sudoers
# Generated by NotLFS Desktop Profile

# User privilege specification
root ALL=(ALL:ALL) ALL
%wheel ALL=(ALL:ALL) ALL

# Allow members of group wheel to execute any command
# (Note: this is the default sudo configuration)
SUDO
chmod 440 ${LFS}/etc/sudoers

# Setup environment variables
cat > ${LFS}/etc/environment << 'ENV'
PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
HOME=/root
USER=root
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
DISPLAY=:0
XDG_RUNTIME_DIR=/run/user/$(id -u)
ENV

# Setup systemd environment (if using systemd)
mkdir -p ${LFS}/etc/systemd
cat > ${LFS}/etc/systemd/system.conf << 'SYSTEMD'
[Manager]
#LogLevel=info
#LogTarget=journal-or-kmsg
#LogColor=yes
#LogLocation=yes
#DumpCore=yes
#CrashShell=yes
#ShowStatus=yes
#CrashChVT=1
#CPUAccounting=yes
#BlockIOAccounting=yes
#MemoryAccounting=yes
#TasksAccounting=yes
#DefaultStandardOutput=journal
#DefaultStandardError=journal
#DefaultTimeoutStartSec=90s
#DefaultTimeoutStopSec=90s
#DefaultRestartSec=100ms
#DefaultStartLimitIntervalSec=60s
#DefaultStartLimitBurst=5
#DefaultEnvironment=LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
#DefaultCPUAccounting=yes
#DefaultBlockIOAccounting=yes
#DefaultMemoryAccounting=yes
#DefaultTasksAccounting=yes
SYSTEMD

echo "=== Desktop Profile: Post-Install Complete ==="
echo ""
echo "Desktop environment setup complete!"
echo ""
echo "To start the desktop environment:"
echo "  1. Reboot into your new system"
echo "  2. The SDDM display manager should start automatically"
echo "  3. Log in with username: root or ${USER_NAME:-user}"
echo "  4. Password: ${ROOT_PASSWORD:-changeme} or ${USER_PASSWORD:-changeme}"
echo ""
echo "If SDDM doesn't start, try:"
echo "  systemctl start sddm    (for systemd)"
echo "  rc-service sddm start   (for openrc)"
echo "  start sddm             (for runit)"
echo ""
echo "To manually start the desktop:"
echo "  startx"
echo "  or"
echo "  startplasma-x11"
echo ""
EOF
    chmod +x "${profile_dir}/hooks/post-install.sh"
    
    log_info "Desktop profile created successfully"
}

# =============================================================================
# PROFILE 4: SERVER
# =============================================================================
#
# The server profile provides a server-oriented Linux system with web,
# database, and file services. It includes everything from the base profile
# plus server-specific packages and configurations.
#
# Use case: Web servers, database servers, file servers, cloud instances,
#           or any headless server environment
#
# Default init system: runit (lightweight, reliable, and simple)
# Estimated build time: 3-6 hours
# Estimated disk space: 2-4 GB
#

create_server_profile() {
    local profile_name="server"
    local profile_dir="${PROFILES_DIR}/${profile_name}"
    
    log_section "Creating SERVER Profile"
    create_profile_directory "$profile_name"
    
    # Create profile.xml
    cat > "${profile_dir}/profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!--
    NotLFS Server Profile
    =====================
    Server-oriented Linux system with web, database, and file services.
    Designed for headless operation with optional GUI.
-->
<profile name="server">
    <description>Server-oriented NotLFS system with web server, database, and file services</description>
    <author>NotLFS Team</author>
    <version>1.0</version>
    
    <!-- Recommended init system - lightweight and reliable -->
    <init_system>runit</init_system>
    
    <!-- Supported init systems -->
    <supported_init_systems>
        <init>runit</init>
        <init>s6-rc</init>
        <init>dinit</init>
        <init>sysv</init>
        <init>systemd</init>
        <init>openrc</init>
    </supported_init_systems>
    
    <!-- Inherit from base profile -->
    <inherits>
        <profile>base</profile>
    </inherits>
    
    <!-- Package selections -->
    <packages>
        <!-- Include all base packages -->
        <include profile="base" />
        
        <!-- Web servers -->
        <include category="web" />
        <package name="nginx" enabled="true" />
        <package name="apache" enabled="false" />
        <package name="lighttpd" enabled="false" />
        
        <!-- Database servers -->
        <include category="database" />
        <package name="postgresql" enabled="true" />
        <package name="mysql" enabled="false" />
        <package name="mariadb" enabled="false" />
        <package name="sqlite" enabled="true" />
        <package name="redis" enabled="true" />
        <package name="memcached" enabled="false" />
        
        <!-- File servers -->
        <package name="samba" enabled="true" />
        <package name="nfs-utils" enabled="true" />
        <package name="vsftpd" enabled="false" />
        <package name="proftpd" enabled="false" />
        
        <!-- Mail servers -->
        <package name="postfix" enabled="true" />
        <package name="dovecot" enabled="false" />
        <package name="opensmtpd" enabled="false" />
        
        <!-- DNS server -->
        <package name="bind" enabled="false" />
        <package name="dnsmasq" enabled="true" />
        
        <!-- Proxy server -->
        <package name="squid" enabled="false" />
        <package name="nginx-proxy" enabled="false" />
        
        <!-- Container tools -->
        <package name="podman" enabled="false" />
        <package name="docker" enabled="false" />
        <package name="runc" enabled="false" />
        <package name="containerd" enabled="false" />
        
        <!-- Monitoring -->
        <package name="netdata" enabled="false" />
        <package name="prometheus" enabled="false" />
        <package name="grafana" enabled="false" />
        <package name="telegraf" enabled="false" />
        <package name="sysstat" enabled="true" />
        <package name="collectd" enabled="false" />
        
        <!-- Logging -->
        <package name="rsyslog" enabled="true" />
        <package name="logrotate" enabled="true" />
        <package name="logwatch" enabled="false" />
        
        <!-- Security -->
        <package name="fail2ban" enabled="true" />
        <package name="iptables" enabled="true" />
        <package name="nftables" enabled="false" />
        <package name="ufw" enabled="false" />
        <package name="openssl" enabled="true" />
        <package name="gnutls" enabled="true" />
        <package name="libgcrypt" enabled="true" />
        
        <!-- SSH server (already in base, but ensure it's enabled) -->
        <package name="openssh" enabled="true" />
        
        <!-- Time synchronization -->
        <package name="chrony" enabled="true" />
        <package name="ntp" enabled="false" />
        <package name="openntpd" enabled="false" />
        
        <!-- Cron -->
        <package name="cronie" enabled="true" />
        <package name="fcron" enabled="false" />
        <package name="anacron" enabled="true" />
        
        <!-- System utilities -->
        <package name="lsof" enabled="true" />
        <package name="strace" enabled="true" />
        <package name="ltrace" enabled="false" />
        <package name="tmux" enabled="true" />
        <package name="screen" enabled="true" />
        <package name="byobu" enabled="false" />
        
        <!-- Text processing -->
        <package name="jq" enabled="true" />
        <package name="yaml-cpp" enabled="false" />
        <package name="xmlstarlet" enabled="false" />
        
        <!-- Compression -->
        <package name="pigz" enabled="true" />
        <package name="pbzip2" enabled="false" />
        <package name="lbzip2" enabled="false" />
        
        <!-- Backup -->
        <package name="tar" enabled="true" />
        <package name="rsync" enabled="true" />
        <package name="restic" enabled="false" />
        <package name="borgbackup" enabled="false" />
        <package name="duplicity" enabled="false" />
        
        <!-- Version control (already in base) -->
        <package name="git" enabled="true" />
        <package name="git-lfs" enabled="false" />
        
        <!-- Development tools -->
        <package name="nodejs" enabled="false" />
        <package name="python3" enabled="true" />
        <package name="ruby" enabled="true" />
        <package name="php" enabled="false" />
        <package name="go" enabled="false" />
        <package name="rust" enabled="false" />
        
        <!-- Database clients -->
        <package name="pgcli" enabled="false" />
        <package name="mycli" enabled="false" />
        <package name="redis-cli" enabled="true" />
        
        <!-- Web development -->
        <package name="curl" enabled="true" />
        <package name="wget" enabled="true" />
        
        <!-- API tools -->
        <package name="httpie" enabled="false" />
        
        <!-- Cloud tools -->
        <package name="aws-cli" enabled="false" />
        <package name="azure-cli" enabled="false" />
        <package name="gcloud-cli" enabled="false" />
    </packages>
    
    <!-- Feature flags -->
    <features>
        <feature name="minimal">false</feature>
        <feature name="network">true</feature>
        <feature name="development">true</feature>
        <feature name="desktop">false</feature>
        <feature name="server">true</feature>
        <feature name="hardening">true</feature>
        <feature name="strip_debug">false</feature>
        <feature name="documents">false</feature>
        <feature name="headless">true</feature>
    </features>
    
    <!-- Server configuration -->
    <server>
        <type>web</type>
        <web_server>nginx</web_server>
        <database>postgresql</database>
        <file_server>samba</file_server>
        <mail_server>postfix</mail_server>
        <dns_server>dnsmasq</dns_server>
        <monitoring>sysstat</monitoring>
        <logging>rsyslog</logging>
        <security>fail2ban</security>
        <time_sync>chrony</time_sync>
        <cron>cronie</cron>
    </server>
    
    <!-- Build configuration -->
    <build>
        <optimization>-O2 -pipe</optimization>
        <jobs>$(nproc)</jobs>
        <strip_debug>false</strip_debug>
        <keep_sources>false</keep_sources>
    </build>
    
    <!-- Security hardening -->
    <security>
        <stack_protector>true</stack_protector>
        <fortify_source>true</fortify_source>
        <relro>true</relro>
        <aslr>true</aslr>
        <pie>true</pie>
        <firewall>iptables</firewall>
    </security>
    
    <!-- Network configuration -->
    <network>
        <hostname>notlfs-server</hostname>
        <domain>local</domain>
        <enable_dhcp>true</enable_dhcp>
        <nameservers>8.8.8.8 8.8.4.4</nameservers>
        <enable_ipv6>true</enable_ipv6>
        <static_ip></static_ip>
        <gateway></gateway>
        <netmask></netmask>
    </network>
    
    <!-- Hooks -->
    <hooks>
        <hook stage="pre-toolchain">
            echo "Building server profile - including server services"
        </hook>
        <hook stage="pre-build">
            echo "Configuring server environment..."
        </hook>
        <hook stage="post-system">
            echo "Setting up server services..."
        </hook>
        <hook stage="post-install">
            echo "Configuring server..."
        </hook>
    </hooks>
</profile>
EOF
    
    # Create packages.list
    cat > "${profile_dir}/packages.list" << 'EOF'
# NotLFS Server Profile - Package List
# =====================================
# Server-oriented system with web, database, and file services

# Include all base packages
include base

# Web servers
nginx

# Database servers
postgresql
sqlite
redis

# File servers
samba
nfs-utils

# Mail servers
postfix

# DNS
chrony
dnsmasq

# Security
fail2ban
iptables
openssl
gnutls
libgcrypt

# Logging
rsyslog
logrotate

# Monitoring
sysstat

# Cron
cronie
anacron

# System utilities
lsof
strace
tmux
screen
jq

# Backup
rsync

# Version control
git

# Programming languages
python3
ruby

# Database clients
redis-cli

# Web tools
curl
wget
EOF
    
    # Create README.md
    cat > "${profile_dir}/README.md" << 'EOF'
# NotLFS Server Profile

## Overview

The **Server** profile provides a server-oriented Linux system with web, database, and file services. It builds upon the base profile and adds everything needed for a production-ready server environment.

## Features

- ✅ **Web Server**: Nginx (with optional Apache)
- ✅ **Database**: PostgreSQL (with optional MySQL/MariaDB)
- ✅ **File Server**: Samba and NFS
- ✅ **Mail Server**: Postfix
- ✅ **DNS**: dnsmasq (with optional BIND)
- ✅ **Security**: fail2ban, iptables, OpenSSL
- ✅ **Monitoring**: sysstat
- ✅ **Logging**: rsyslog, logrotate
- ✅ **Time Sync**: chrony
- ✅ **Cron**: cronie, anacron
- ✅ **SSH Server**: OpenSSH
- ✅ **Headless**: No GUI by default

## Use Cases

- Web servers (Nginx, Apache)
- Database servers (PostgreSQL, MySQL)
- File servers (Samba, NFS)
- Mail servers (Postfix, Dovecot)
- DNS servers (dnsmasq, BIND)
- Cloud instances
- Container hosts
- Development servers
- Production servers

## Default Init System

**runit** - A lightweight, reliable, and simple init system that's perfect for servers:
- Simple configuration
- Fast startup
- Reliable process supervision
- Easy to manage

Alternative supported init systems:
- **s6-rc** - Dependency-based service management
- **dinit** - Fast, dependency-based init
- **sysv** - Traditional SysV init
- **systemd** - Full-featured system and service manager
- **openrc** - OpenRC init system

## Package Selection

### Included Categories
- All packages from the **base** profile
- `web` - Web server packages
- `database` - Database server packages

### Web Server
- **nginx** - High-performance web server (default)
- Apache - Alternative web server (disabled by default)
- lighttpd - Lightweight web server (disabled by default)

### Database Servers
- **postgresql** - Advanced relational database (default)
- MySQL - Popular relational database (disabled by default)
- MariaDB - MySQL-compatible database (disabled by default)
- **sqlite** - Embedded database
- **redis** - In-memory data structure store
- memcached - Memory caching system (disabled by default)

### File Servers
- **samba** - SMB/CIFS file server
- **nfs-utils** - NFS file server
- vsftpd - FTP server (disabled by default)
- proftpd - FTP server (disabled by default)

### Mail Servers
- **postfix** - Mail transfer agent
- Dovecot - IMAP/POP3 server (disabled by default)
- opensmtpd - SMTP server (disabled by default)

### DNS
- **dnsmasq** - Lightweight DNS and DHCP server
- BIND - Full-featured DNS server (disabled by default)

### Security
- **fail2ban** - Intrusion prevention
- **iptables** - Firewall
- **OpenSSL** - SSL/TLS toolkit
- **GnuTLS** - Alternative TLS implementation
- **libgcrypt** - Cryptographic library

### Monitoring
- **sysstat** - System performance monitoring
- netdata - Real-time monitoring (disabled by default)
- prometheus - Monitoring system (disabled by default)
- grafana - Visualization (disabled by default)

### Logging
- **rsyslog** - System logging
- **logrotate** - Log rotation
- logwatch - Log analysis (disabled by default)

### Time Synchronization
- **chrony** - NTP client/server
- ntp - Alternative NTP client (disabled by default)
- openntpd - Alternative NTP daemon (disabled by default)

### Cron
- **cronie** - Cron daemon
- **anacron** - Anacron for systems not running 24/7
- fcron - Alternative cron (disabled by default)

### System Utilities
- lsof - List open files
- strace - System call tracer
- tmux - Terminal multiplexer
- screen - Terminal multiplexer
- jq - JSON processor

### Development Tools
- git - Version control
- python3 - Python interpreter
- ruby - Ruby interpreter

## Customization

### Adding More Services

To add additional services to the server profile:

```xml
<profile name="my-server">
    <include profile="server" />
    <packages>
        <!-- Add Docker support -->
        <package name="podman" enabled="true" />
        <package name="runc" enabled="true" />
        <package name="containerd" enabled="true" />
        
        <!-- Add monitoring -->
        <package name="netdata" enabled="true" />
        <package name="prometheus" enabled="true" />
        <package name="grafana" enabled="true" />
        
        <!-- Add PHP support -->
        <package name="php" enabled="true" />
        <package name="php-fpm" enabled="true" />
        <package name="php-gd" enabled="true" />
        <package name="php-mysql" enabled="true" />
        <package name="php-pgsql" enabled="true" />
    </packages>
</profile>
```

### Changing the Web Server

To use Apache instead of Nginx:

```xml
<profile name="apache-server">
    <include profile="server" />
    <packages>
        <package name="nginx" enabled="false" />
        <package name="apache" enabled="true" />
        <package name="apache-mod-php" enabled="true" />
        <package name="apache-mod-ssl" enabled="true" />
    </packages>
    <server>
        <web_server>apache</web_server>
    </server>
</profile>
```

### Changing the Database

To use MySQL instead of PostgreSQL:

```xml
<profile name="mysql-server">
    <include profile="server" />
    <packages>
        <package name="postgresql" enabled="false" />
        <package name="mysql" enabled="true" />
    </packages>
    <server>
        <database>mysql</database>
    </server>
</profile>
```

### Creating a LAMP Server

To create a LAMP (Linux, Apache, MySQL, PHP) server:

```xml
<profile name="lamp-server">
    <include profile="server" />
    <packages>
        <!-- Web server -->
        <package name="nginx" enabled="false" />
        <package name="apache" enabled="true" />
        
        <!-- Database -->
        <package name="postgresql" enabled="false" />
        <package name="mysql" enabled="true" />
        
        <!-- PHP -->
        <package name="php" enabled="true" />
        <package name="php-fpm" enabled="true" />
        <package name="php-mysql" enabled="true" />
        <package name="php-gd" enabled="true" />
        <package name="php-mbstring" enabled="true" />
        <package name="php-xml" enabled="true" />
        <package name="php-curl" enabled="true" />
        
        <!-- Apache PHP module -->
        <package name="apache-mod-php" enabled="true" />
    </packages>
    <server>
        <type>lamp</type>
        <web_server>apache</web_server>
        <database>mysql</database>
    </server>
</profile>
```

### Creating a LEMP Server

To create a LEMP (Linux, Nginx, MySQL, PHP) server:

```xml
<profile name="lemp-server">
    <include profile="server" />
    <packages>
        <!-- Database -->
        <package name="postgresql" enabled="false" />
        <package name="mysql" enabled="true" />
        
        <!-- PHP -->
        <package name="php" enabled="true" />
        <package name="php-fpm" enabled="true" />
        <package name="php-mysql" enabled="true" />
        <package name="php-gd" enabled="true" />
        <package name="php-mbstring" enabled="true" />
    </packages>
    <server>
        <type>lemp</type>
        <web_server>nginx</web_server>
        <database>mysql</database>
    </server>
</profile>
```

## Build Configuration

```bash
# Build with server profile
./notlfs.sh -p server

# Build with runit (default)
./notlfs.sh -p server -i runit

# Build with s6-rc
./notlfs.sh -p server -i s6-rc

# Build with systemd
./notlfs.sh -p server -i systemd

# Build with more parallel jobs
./notlfs.sh -p server --jobs 8

# Build in auto mode (unattended)
./notlfs.sh -p server -m auto

# Build in interactive mode (recommended)
./notlfs.sh -p server -m interactive
```

## Post-Installation

After installation, you'll have a production-ready server environment.

### First Boot

1. The system will boot to a console (no GUI)
2. Log in with the root account
3. Set up networking if not using DHCP
4. Configure services as needed

### Setting Up Networking

#### Static IP Configuration

Edit `/etc/network/interfaces`:

```
# Static IP configuration
auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
```

Then restart networking:
```bash
# For sysvinit
service networking restart

# For runit
sv restart networking

# For s6-rc
s6-rc -d change networking
s6-rc -u change networking

# For systemd
systemctl restart networking
```

#### Hostname Configuration

```bash
# Set hostname
echo "myserver" > /etc/hostname
hostname -F /etc/hostname

# Edit /etc/hosts
nano /etc/hosts
# Add: 192.168.1.100 myserver.mydomain.com myserver
```

### Starting Services

#### With runit (default)

```bash
# List all services
sv status /etc/service/*

# Start a service
sv up <service>

# Stop a service
sv down <service>

# Restart a service
sv restart <service>

# Check service status
sv status <service>
```

#### With s6-rc

```bash
# List all services
s6-rc-db list

# Start a service
s6-rc -u change <service>

# Stop a service
s6-rc -d change <service>

# Check service status
s6-rc -a list
```

#### With systemd

```bash
# List all services
systemctl list-units --type=service

# Start a service
systemctl start <service>

# Enable a service at boot
systemctl enable <service>

# Stop a service
systemctl stop <service>

# Check service status
systemctl status <service>
```

### Configuring Services

#### Nginx Web Server

```bash
# Test configuration
nginx -t

# Start Nginx
sv up nginx  # runit
s6-rc -u change nginx  # s6-rc
systemctl start nginx  # systemd

# Stop Nginx
sv down nginx
s6-rc -d change nginx
systemctl stop nginx

# Restart Nginx
sv restart nginx
s6-rc -d change nginx
s6-rc -u change nginx
systemctl restart nginx
```

Configuration files:
- `/etc/nginx/nginx.conf` - Main configuration
- `/etc/nginx/conf.d/` - Site configurations
- `/etc/nginx/sites-available/` - Available sites
- `/etc/nginx/sites-enabled/` - Enabled sites

#### PostgreSQL Database

```bash
# Initialize database
su - postgres -c "initdb -D /var/lib/postgresql/data"

# Start PostgreSQL
sv up postgresql
s6-rc -u change postgresql
systemctl start postgresql

# Create a user
su - postgres -c "createuser myuser"

# Create a database
su - postgres -c "createdb mydb -O myuser"

# Access PostgreSQL
su - postgres -c "psql"
```

Configuration files:
- `/etc/postgresql/<version>/main/pg_hba.conf` - Client authentication
- `/etc/postgresql/<version>/main/postgresql.conf` - Main configuration

#### Samba File Server

```bash
# Start Samba
sv up samba
s6-rc -u change samba
systemctl start smbd
systemctl start nmbd

# Create a share
mkdir -p /srv/samba/myshare
chmod 777 /srv/samba/myshare

# Edit configuration
nano /etc/samba/smb.conf
```

Add to `/etc/samba/smb.conf`:
```ini
[myshare]
    comment = My Shared Folder
    path = /srv/samba/myshare
    browseable = yes
    read only = no
    guest ok = no
    create mask = 0775
    directory mask = 0775
```

Restart Samba:
```bash
sv restart samba
s6-rc -d change samba
s6-rc -u change samba
systemctl restart smbd
systemctl restart nmbd
```

#### Postfix Mail Server

```bash
# Start Postfix
sv up postfix
s6-rc -u change postfix
systemctl start postfix

# Test mail
echo "Test message" | mail -s "Test Subject" user@localhost

# Check mail queue
mailq
```

Configuration files:
- `/etc/postfix/main.cf` - Main configuration
- `/etc/postfix/master.cf` - Master configuration

#### dnsmasq DNS Server

```bash
# Start dnsmasq
sv up dnsmasq
s6-rc -u change dnsmasq
systemctl start dnsmasq

# Test DNS
dig @localhost example.com
nslookup example.com localhost
```

Configuration file:
- `/etc/dnsmasq.conf` - Main configuration

#### fail2ban

```bash
# Start fail2ban
sv up fail2ban
s6-rc -u change fail2ban
systemctl start fail2ban

# Check fail2ban status
fail2ban-client status

# Check fail2ban logs
tail -f /var/log/fail2ban.log
```

Configuration files:
- `/etc/fail2ban/jail.local` - Local jail configuration
- `/etc/fail2ban/jail.d/` - Custom jail configurations

#### chrony Time Synchronization

```bash
# Start chrony
sv up chrony
s6-rc -u change chrony
systemctl start chronyd

# Check chrony status
chronyc tracking
chronyc sources
chronyc sourcestats
```

Configuration file:
- `/etc/chrony.conf` - Main configuration

#### rsyslog

```bash
# Start rsyslog
sv up rsyslog
s6-rc -u change rsyslog
systemctl start rsyslog

# Check logs
tail -f /var/log/syslog
tail -f /var/log/messages
```

Configuration files:
- `/etc/rsyslog.conf` - Main configuration
- `/etc/rsyslog.d/` - Custom configurations

### Creating a User

It's recommended to create a regular user account for daily administration:

```bash
# Add a user
useradd -m -G wheel,adm,systemd-journal myuser
passwd myuser

# Add to sudoers (if using sudo)
echo "myuser ALL=(ALL) ALL" >> /etc/sudoers

# Or use visudo
visudo
```

### Setting Up SSH

```bash
# Start SSH
sv up sshd
s6-rc -u change sshd
systemctl start sshd

# Enable SSH at boot
ln -s /etc/service/sshd /etc/service/sshd  # runit
ln -sf /etc/s6-rc/databases/available/sshd /etc/s6-rc/databases/current/sshd  # s6-rc
systemctl enable sshd  # systemd

# Configure SSH
nano /etc/ssh/sshd_config

# Restart SSH
sv restart sshd
s6-rc -d change sshd
s6-rc -u change sshd
systemctl restart sshd
```

### Setting Up a Firewall

Using iptables:

```bash
# Basic firewall rules
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # SSH
iptables -A INPUT -p tcp --dport 80 -j ACCEPT  # HTTP
iptables -A INPUT -p tcp --dport 443 -j ACCEPT # HTTPS
iptables -A INPUT -j DROP

# Save rules (if iptables-persistent is installed)
iptables-save > /etc/iptables/rules.v4

# Or use fail2ban for automatic blocking
```

### Setting Up Cron Jobs

```bash
# Start cron
sv up cronie
s6-rc -u change cronie
systemctl start cronie

# Edit root crontab
crontab -e

# Edit user crontab
crontab -u myuser -e
```

### Monitoring System Resources

```bash
# Check system load
top
htop

# Check memory usage
free -h
vmstat 1

# Check disk usage
df -h
du -sh /path/to/directory

# Check network
ip a
ip route
ss -tuln
netstat -tuln

# Check running processes
ps aux
ps -ef

# Check system uptime
uptime

# Check system information
uname -a
cat /proc/cpuinfo
cat /proc/meminfo
```

### Log Management

```bash
# View logs
tail -f /var/log/syslog
tail -f /var/log/messages
journalctl -f  # systemd

# Check log size
du -sh /var/log/*

# Rotate logs manually
logrotate -f /etc/logrotate.conf

# Configure log rotation
nano /etc/logrotate.conf
nano /etc/logrotate.d/<service>
```

## Security Hardening

### SSH Hardening

Edit `/etc/ssh/sshd_config`:

```ini
# Change default port
Port 2222

# Disable root login
PermitRootLogin no

# Use key-based authentication only
PasswordAuthentication no
PubkeyAuthentication yes

# Disable empty passwords
PermitEmptyPasswords no

# Limit user access
AllowUsers myuser

# Disable X11 forwarding (if not needed)
X11Forwarding no

# Disable agent forwarding
AllowAgentForwarding no

# Disable TCP forwarding
AllowTcpForwarding no
```

Then restart SSH:
```bash
sv restart sshd
s6-rc -d change sshd
s6-rc -u change sshd
systemctl restart sshd
```

### fail2ban Configuration

Edit `/etc/fail2ban/jail.local`:

```ini
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 5
```

Then restart fail2ban:
```bash
sv restart fail2ban
s6-rc -d change fail2ban
s6-rc -u change fail2ban
systemctl restart fail2ban
```

### Firewall Configuration

Create `/etc/iptables/rules.v4`:

```bash
#!/bin/sh

# Flush all rules
iptables -F
iptables -X

# Set default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP and HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow ping
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# Log dropped packets
iptables -A INPUT -j LOG --log-prefix "IPTables-Dropped: " --log-level 4

# Drop everything else
iptables -A INPUT -j DROP
```

Make it executable and load it:
```bash
chmod +x /etc/iptables/rules.v4
/etc/iptables/rules.v4

# Save rules
iptables-save > /etc/iptables/rules.v4
```

To restore rules at boot, create a service or add to `/etc/rc.local`.

### Automatic Security Updates

Install and configure unattended-upgrades (if using a package manager):

```bash
# For Debian/Ubuntu
apt-get install unattended-upgrades

# Edit configuration
nano /etc/apt/apt.conf.d/50unattended-upgrades
```

## Performance Optimization

### Kernel Parameters

Edit `/etc/sysctl.conf`:

```ini
# Network performance
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15

# Memory performance
vm.swappiness = 10
vm.vfs_cache_pressure = 50

# File system performance
fs.file-max = 100000
fs.inotify.max_user_watches = 524288
```

Apply changes:
```bash
sysctl -p
```

### Nginx Performance

Edit `/etc/nginx/nginx.conf`:

```nginx
worker_processes auto;
worker_connections 1024;

# Use epoll for Linux
use epoll;

# Enable gzip compression
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml application/json application/javascript application/xml application/xml+rss text/javascript;

# Enable keepalive
keepalive_timeout 75s;
keepalive_requests 100;

# Enable sendfile
sendfile on;
tcp_nopush on;
tcp_nodelay on;

# Timeouts
client_header_timeout 10s;
client_body_timeout 10s;
keepalive_timeout 15s;
send_timeout 10s;

# Buffer sizes
client_header_buffer_size 2k;
large_client_header_buffers 4 8k;
client_body_buffer_size 16k;

# Open file cache
open_file_cache max=1000 inactive=20s;
open_file_cache_valid 30s;
open_file_cache_min_uses 2;
open_file_cache_errors on;
```

### PostgreSQL Performance

Edit `/etc/postgresql/<version>/main/postgresql.conf`:

```ini
# Memory settings
shared_buffers = 25% of total RAM
work_mem = 16MB
effective_cache_size = 75% of total RAM
maintenance_work_mem = 2GB

# WAL settings
wal_buffers = 16MB
checkpoint_segments = 8
checkpoint_completion_target = 0.9

# Query planner
random_page_cost = 1.1
effective_io_concurrency = 200

# Parallel query
max_worker_processes = 4
max_parallel_workers_per_gather = 2
max_parallel_workers = 4
```

### PHP Performance

Edit `/etc/php/<version>/fpm/php.ini`:

```ini
memory_limit = 256M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300
max_input_time = 300

# Enable OPcache
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
```

## Backup and Recovery

### Backup Strategy

1. **Database Backup**
   ```bash
   # PostgreSQL
   su - postgres -c "pg_dumpall > /backup/postgresql-$(date +%F).sql"
   
   # MySQL
   mysqldump -u root -p --all-databases > /backup/mysql-$(date +%F).sql
   ```

2. **File System Backup**
   ```bash
   # Full backup
   tar -czvf /backup/full-$(date +%F).tar.gz --exclude=/backup --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run /
   
   # Incremental backup
   tar -czvf /backup/incremental-$(date +%F).tar.gz --newer-mtime="1 day ago" --exclude=/backup --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run /
   ```

3. **Rsync Backup**
   ```bash
   # Backup to another server
   rsync -avz --delete /path/to/backup user@backup-server:/backup/notlfs/
   ```

4. **Automated Backup Script**
   ```bash
   #!/bin/bash
   # /usr/local/bin/backup.sh
   
   DATE=$(date +%F)
   BACKUP_DIR="/backup"
   
   # Create backup directory
   mkdir -p $BACKUP_DIR/$DATE
   
   # Backup databases
   su - postgres -c "pg_dumpall > $BACKUP_DIR/$DATE/postgresql.sql" 2>/dev/null
   
   # Backup files
   tar -czvf $BACKUP_DIR/$DATE/files.tar.gz --exclude=/backup --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run /
   
   # Clean up old backups (keep last 7 days)
   find $BACKUP_DIR -type d -mtime +7 -exec rm -rf {} \;
   ```

### Restore Strategy

1. **Database Restore**
   ```bash
   # PostgreSQL
   su - postgres -c "psql -f /backup/postgresql-2024-01-01.sql"
   
   # MySQL
   mysql -u root -p < /backup/mysql-2024-01-01.sql
   ```

2. **File System Restore**
   ```bash
   # Full restore
   tar -xzvf /backup/full-2024-01-01.tar.gz -C /
   
   # Partial restore
   tar -xzvf /backup/full-2024-01-01.tar.gz -C / path/to/restore
   ```

### Disaster Recovery

1. **Create a rescue system**
   ```bash
   # Build a minimal NotLFS system on a USB drive
   # Use it to boot and repair the main system
   ```

2. **Document your configuration**
   ```bash
   # Save all configuration files
   tar -czvf /backup/config-$(date +%F).tar.gz /etc /home/*/.config /home/*/.ssh
   ```

3. **Test your backups regularly**
   ```bash
   # Test database restore
   su - postgres -c "psql -f /backup/postgresql-test.sql"
   
   # Test file restore
   mkdir /tmp/restore-test
   tar -xzvf /backup/full-test.tar.gz -C /tmp/restore-test
   ls -la /tmp/restore-test/etc
   ```

## Monitoring and Alerts

### Basic Monitoring

```bash
# Check system health
uptime
free -h
df -h

# Check service status
sv status /*  # runit
s6-rc -a list  # s6-rc
systemctl status *  # systemd

# Check logs
tail -n 100 /var/log/syslog
tail -n 100 /var/log/messages
journalctl -n 100  # systemd
```

### sysstat Monitoring

sysstat is included by default and provides:
- CPU usage (`sar -u`)
- Memory usage (`sar -r`)
- I/O usage (`sar -b`)
- Network usage (`sar -n`)
- Process statistics (`sar -q`)

View historical data:
```bash
# Today's data
sar -A

# Yesterday's data
sar -f /var/log/sa/sa$(date -d yesterday +%d)

# Specific date
sar -f /var/log/sa/sa01
```

Configure sysstat (`/etc/default/sysstat` or `/etc/sysconfig/sysstat`):
```ini
# Collect data every 10 seconds
SADC_PATH=/usr/lib64/sa/sadc
SYSTAT_PATH=/usr/bin
# Activity reports for the system
ACTIVITY=yes
# 10 seconds interval
INTERVAL=10
# Save historical data for 7 days
HISTORY=7
```

### Custom Monitoring Script

Create `/usr/local/bin/monitor.sh`:

```bash
#!/bin/bash

# System Monitoring Script

EMAIL="admin@example.com"
THRESHOLD_CPU=90
THRESHOLD_MEM=90
THRESHOLD_DISK=90

# Get current values
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
MEM_USAGE=$(free | awk '/Mem:/ {printf("%.0f", $3/$2*100)}')
DISK_USAGE=$(df -h | awk '$NF=="/" {print $5}' | tr -d '%')

# Check CPU
if [ "$CPU_USAGE" -gt "$THRESHOLD_CPU" ]; then
    echo "ALERT: High CPU usage: ${CPU_USAGE}%" | mail -s "CPU Alert on $(hostname)" $EMAIL
fi

# Check Memory
if [ "$MEM_USAGE" -gt "$THRESHOLD_MEM" ]; then
    echo "ALERT: High Memory usage: ${MEM_USAGE}%" | mail -s "Memory Alert on $(hostname)" $EMAIL
fi

# Check Disk
if [ "$DISK_USAGE" -gt "$THRESHOLD_DISK" ]; then
    echo "ALERT: High Disk usage: ${DISK_USAGE}%" | mail -s "Disk Alert on $(hostname)" $EMAIL
fi

# Check services
for service in nginx postgresql samba; do
    if ! sv status $service | grep -q running; then
        echo "ALERT: Service $service is not running" | mail -s "Service Alert on $(hostname)" $EMAIL
    fi
done
```

Make it executable and add to cron:
```bash
chmod +x /usr/local/bin/monitor.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/monitor.sh") | crontab -
```

## Deployment Strategies

### Single Server Deployment

1. Build the server profile
2. Install to disk
3. Configure services
4. Deploy

### Multi-Server Deployment

1. **Build a base image**
   ```bash
   # Build NotLFS with server profile
   ./notlfs.sh -p server -m auto
   
   # Create a disk image
   dd if=/dev/sda of=/backup/notlfs-server.img bs=4M
   ```

2. **Deploy to multiple servers**
   ```bash
   # Copy image to new server
   dd if=/backup/notlfs-server.img of=/dev/sda bs=4M
   
   # Or use rsync
   rsync -avz /backup/notlfs-server.img root@new-server:/backup/
   ```

3. **Customize each server**
   ```bash
   # On each server, configure:
   # - Hostname
   # - IP address
   # - Services
   # - Applications
   ```

### Container Deployment

While NotLFS itself doesn't include container tools by default, you can add them:

```bash
# Add Docker/Podman to the server profile
./notlfs.sh -p server --add-package podman --add-package runc

# Build container images
podman build -t myapp .

# Run containers
podman run -d --name web -p 80:80 myapp
```

### Cloud Deployment

For cloud providers:

1. **Create a cloud image**
   ```bash
   # Build NotLFS
   ./notlfs.sh -p server -m auto
   
   # Create a qcow2 image
   qemu-img convert -f raw -O qcow2 /dev/sda notlfs-server.qcow2
   
   # Upload to cloud provider
   glance image-create --name "NotLFS Server" --disk-format qcow2 --container-format bare < notlfs-server.qcow2
   ```

2. **Deploy instances**
   ```bash
   # Using OpenStack
   nova boot --image "NotLFS Server" --flavor m1.medium my-server
   ```

### Configuration Management

Use configuration management tools to manage multiple servers:

1. **Ansible**
   ```bash
   # Install Ansible on a control node
   pip install ansible
   
   # Create inventory file
   cat > inventory.ini << 'EOF'
   [webservers]
   web1 ansible_host=192.168.1.10
   web2 ansible_host=192.168.1.11
   
   [dbservers]
   db1 ansible_host=192.168.1.20
   
   [fileservers]
   fs1 ansible_host=192.168.1.30
   EOF
   
   # Create playbook
   cat > nginx.yml << 'EOF'
   ---
   - name: Configure Nginx servers
     hosts: webservers
     tasks:
       - name: Install Nginx
         package:
           name: nginx
           state: present
       
       - name: Start Nginx
         service:
           name: nginx
           state: started
           enabled: yes
       
       - name: Deploy configuration
         copy:
           src: files/nginx.conf
           dest: /etc/nginx/nginx.conf
         notify: restart nginx
     
     handlers:
       - name: restart nginx
         service:
           name: nginx
           state: restarted
   EOF
   
   # Run playbook
   ansible-playbook -i inventory.ini nginx.yml
   ```

2. **Puppet**
3. **Chef**
4. **SaltStack**

## Maintenance Tasks

### Regular Maintenance

1. **Update packages**
   ```bash
   # If using a package manager
   xbps-install -Su  # Void Linux
   nix-env -u       # Nix
   apk update        # Alpine
   ```

2. **Check for security updates**
   ```bash
   # Check NotLFS for updates
   cd /usr/local/notlfs
   git pull
   ```

3. **Rotate logs**
   ```bash
   logrotate -f /etc/logrotate.conf
   ```

4. **Clean up temporary files**
   ```bash
   # Clean /tmp
   find /tmp -type f -atime +7 -delete
   
   # Clean package cache
   rm -rf /var/cache/*
   ```

5. **Check disk space**
   ```bash
   df -h
   du -sh /var/*
   ```

### Monthly Maintenance

1. **Test backups**
   ```bash
   # Test restore from backup
   mkdir /tmp/restore-test
   tar -xzvf /backup/full-$(date -d "1 month ago" +%F).tar.gz -C /tmp/restore-test
   ```

2. **Update documentation**
   ```bash
   # Update system documentation
   nano /etc/motd
   ```

3. **Review security**
   ```bash
   # Check for open ports
   ss -tuln
   
   # Check for listening services
   netstat -tuln
   
   # Check fail2ban
   fail2ban-client status
   
   # Check firewall
   iptables -L -n -v
   ```

4. **Test disaster recovery**
   ```bash
   # Test booting from rescue system
   # Test restoring from backup
   ```

### Quarterly Maintenance

1. **Update kernel**
   ```bash
   # Rebuild NotLFS with updated kernel
   ./notlfs.sh -p server --kernel-version 6.7.0
   ```

2. **Update all packages**
   ```bash
   # Rebuild all packages from source
   ./notlfs.sh -p server --force-rebuild
   ```

3. **Review and update configurations**
   ```bash
   # Review all configuration files
   find /etc -type f -name "*.conf" -exec echo "File: {}" \; -exec cat {} \;
   ```

4. **Test failover**
   ```bash
   # Test failover to backup server
   # Test database replication
   ```

## Troubleshooting

### Common Issues

1. **Service fails to start**
   ```bash
   # Check service logs
   tail -f /var/log/<service>.log
   
   # Check system logs
   tail -f /var/log/syslog
   
   # Test service manually
   /usr/bin/<service> --debug
   ```

2. **Network connectivity issues**
   ```bash
   # Check network interface
   ip a
   
   # Check routing
   ip route
   
   # Check DNS
   cat /etc/resolv.conf
   nslookup example.com
   
   # Check firewall
   iptables -L -n -v
   
   # Test connectivity
   ping google.com
   curl -I https://example.com
   ```

3. **Disk space issues**
   ```bash
   # Check disk usage
   df -h
   
   # Check largest directories
   du -sh /*
   du -sh /var/*
   
   # Clean up
   find /tmp -type f -atime +7 -delete
   find /var/log -type f -size +10M -exec truncate -s 0 {} \;
   ```

4. **Memory issues**
   ```bash
   # Check memory usage
   free -h
   
   # Check running processes
   ps aux --sort=-%mem | head
   
   # Check swap
   swapon --show
   free -h
   ```

5. **Permission issues**
   ```bash
   # Check file permissions
   ls -la /path/to/file
   
   # Check ownership
   ls -la /path/to/directory
   
   # Fix permissions
   chmod 644 /path/to/file
   chown user:group /path/to/file
   ```

### Debugging Services

1. **Check service status**
   ```bash
   # runit
   sv status <service>
   
   # s6-rc
   s6-rc -a list
   s6-svstat /etc/s6/<service>
   
   # systemd
   systemctl status <service>
   journalctl -u <service>
   ```

2. **Check service logs**
   ```bash
   tail -f /var/log/<service>.log
   tail -f /var/log/syslog | grep <service>
   ```

3. **Test service manually**
   ```bash
   # Run service in foreground
   /usr/bin/<service> --foreground --debug
   
   # Check configuration
   /usr/bin/<service> --test-config
   ```

4. **Check dependencies**
   ```bash
   # Check if required files exist
   ldd /usr/bin/<service>
   
   # Check if required libraries are installed
   pkg-config --modversion <library>
   ```

### Network Troubleshooting

1. **Check network interface**
   ```bash
   ip a
   ifconfig
   ```

2. **Check routing**
   ```bash
   ip route
   route -n
   ```

3. **Check DNS**
   ```bash
   cat /etc/resolv.conf
   nslookup example.com
   dig example.com
   ```

4. **Check connectivity**
   ```bash
   ping 8.8.8.8
   ping google.com
   curl -I https://example.com
   wget -qO- https://example.com
   ```

5. **Check firewall**
   ```bash
   iptables -L -n -v
   nft list ruleset
   ```

6. **Check listening ports**
   ```bash
   ss -tuln
   netstat -tuln
   lsof -i
   ```

### Performance Troubleshooting

1. **Check system load**
   ```bash
   uptime
   top
   htop
   ```

2. **Check CPU usage**
   ```bash
   mpstat -P ALL
   sar -u
   ```

3. **Check memory usage**
   ```bash
   free -h
   vmstat 1
   sar -r
   ```

4. **Check I/O usage**
   ```bash
   iostat -x 1
   sar -b
   ```

5. **Check network usage**
   ```bash
   iftop
   nload
   sar -n
   ```

6. **Check disk I/O**
   ```bash
   iostat -d 1
   dstat
   ```

### Log Analysis

1. **Check system logs**
   ```bash
   tail -f /var/log/syslog
   tail -f /var/log/messages
   ```

2. **Check service-specific logs**
   ```bash
   tail -f /var/log/nginx/error.log
   tail -f /var/log/postgresql/postgresql-*.log
   ```

3. **Search logs**
   ```bash
   grep -i error /var/log/syslog
   grep -i fail /var/log/*
   ```

4. **Analyze logs**
   ```bash
   # Count errors
   grep -c error /var/log/syslog
   
   # Show unique errors
   grep error /var/log/syslog | sort | uniq
   
   # Show recent errors
   grep error /var/log/syslog | tail -20
   ```

## Notes

- This profile is **headless by default** (no GUI). To add GUI support, include the desktop profile or add individual GUI packages.
- The default init system is **runit**, which is lightweight and reliable for servers. However, **systemd** is recommended for complex server environments.
- **PostgreSQL** is the default database. **MySQL/MariaDB** can be added as alternatives.
- **Nginx** is the default web server. **Apache** can be added as an alternative.
- **Samba** and **NFS** are included for file sharing. Choose based on your needs.
- **Postfix** is included for mail. For a full mail server, add **Dovecot**.
- **fail2ban** is included for security. Configure it to protect your services.
- **iptables** is included for firewall. Consider using **nftables** for modern systems.
- **chrony** is included for time synchronization. It's more accurate than traditional ntp.
- The build process may take **3-6 hours** depending on your hardware.
- Disk space requirement is approximately **2-4 GB**.
- All source code is downloaded and compiled from scratch.
EOF
    
    # Create service definitions for runit
    mkdir -p "${profile_dir}/services/runit"
    cat > "${profile_dir}/services/runit/README.md" << 'EOF'
# Server Profile - runit Service Definitions

This directory contains service definitions for the runit init system when using the server profile.

## Default Services

The server profile includes the following services with runit:

1. **sshd** - OpenSSH server
2. **nginx** - Web server
3. **postgresql** - PostgreSQL database
4. **redis** - Redis key-value store
5. **samba** - Samba file server
6. **nfs-server** - NFS file server
7. **postfix** - Mail transfer agent
8. **dnsmasq** - DNS and DHCP server
9. **chrony** - Time synchronization
10. **cronie** - Cron daemon
11. **rsyslog** - System logging
12. **fail2ban** - Intrusion prevention
13. **iptables** - Firewall (if using iptables-persistent)

## Service Structure

Each service in runit has the following structure:

```
/etc/service/<service-name>/
└── run
```

The `run` script is the main executable that starts the service. It should:
- Run in the foreground (or use `exec` to replace the shell process)
- Handle signals properly
- Log to stdout/stderr (runit will capture this)

## Creating Service Definitions

### Example: Nginx Web Server

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/nginx
   ```

2. Create the run script (`/etc/service/nginx/run`):
   ```bash
   #!/bin/sh
   exec /usr/sbin/nginx -g "daemon off;"
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/nginx/run
   ```

4. Start the service:
   ```bash
   sv up nginx
   ```

5. Check status:
   ```bash
   sv status nginx
   ```

6. View logs:
   ```bash
   sv log nginx
   tail -f /etc/service/nginx/log/main/current
   ```

### Example: PostgreSQL Database

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/postgresql
   ```

2. Create the run script (`/etc/service/postgresql/run`):
   ```bash
   #!/bin/sh
   exec su - postgres -c "/usr/lib/postgresql/bin/postgres -D /var/lib/postgresql/data -c config_file=/etc/postgresql/postgresql.conf"
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/postgresql/run
   ```

4. Start the service:
   ```bash
   sv up postgresql
   ```

> **Note**: Before starting PostgreSQL, you need to initialize the database:
> ```bash
> su - postgres -c "initdb -D /var/lib/postgresql/data"
> ```

### Example: Samba File Server

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/samba
   ```

2. Create the run script (`/etc/service/samba/run`):
   ```bash
   #!/bin/sh
   exec /usr/sbin/smbd -F
   ```

3. Create a separate service for nmbd:
   ```bash
   mkdir -p /etc/service/nmbd
   cat > /etc/service/nmbd/run << 'EOF'
   #!/bin/sh
   exec /usr/sbin/nmbd -F
   EOF
   chmod +x /etc/service/nmbd/run
   ```

4. Start the services:
   ```bash
   sv up samba
   sv up nmbd
   ```

### Example: OpenSSH Server

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/sshd
   ```

2. Create the run script (`/etc/service/sshd/run`):
   ```bash
   #!/bin/sh
   exec /usr/sbin/sshd -D
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/sshd/run
   ```

4. Start the service:
   ```bash
   sv up sshd
   ```

### Example: Redis Key-Value Store

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/redis
   ```

2. Create the run script (`/etc/service/redis/run`):
   ```bash
   #!/bin/sh
   exec su - redis -c "/usr/bin/redis-server /etc/redis/redis.conf"
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/redis/run
   ```

4. Start the service:
   ```bash
   sv up redis
   ```

### Example: chrony Time Synchronization

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/chrony
   ```

2. Create the run script (`/etc/service/chrony/run`):
   ```bash
   #!/bin/sh
   exec /usr/sbin/chronyd -f /etc/chrony.conf
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/chrony/run
   ```

4. Start the service:
   ```bash
   sv up chrony
   ```

### Example: cronie Cron Daemon

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/cronie
   ```

2. Create the run script (`/etc/service/cronie/run`):
   ```bash
   #!/bin/sh
   exec /usr/sbin/cronie
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/cronie/run
   ```

4. Start the service:
   ```bash
   sv up cronie
   ```

### Example: rsyslog System Logging

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/rsyslog
   ```

2. Create the run script (`/etc/service/rsyslog/run`):
   ```bash
   #!/bin/sh
   exec /usr/sbin/rsyslogd -n
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/rsyslog/run
   ```

4. Start the service:
   ```bash
   sv up rsyslog
   ```

### Example: fail2ban Intrusion Prevention

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/fail2ban
   ```

2. Create the run script (`/etc/service/fail2ban/run`):
   ```bash
   #!/bin/sh
   exec /usr/bin/fail2ban-server -b -s /var/run/fail2ban/fail2ban.sock -p /var/run/fail2ban/fail2ban.pid
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/fail2ban/run
   ```

4. Start the service:
   ```bash
   sv up fail2ban
   ```

### Example: dnsmasq DNS Server

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/dnsmasq
   ```

2. Create the run script (`/etc/service/dnsmasq/run`):
   ```bash
   #!/bin/sh
   exec /usr/sbin/dnsmasq -k -x /var/run/dnsmasq/dnsmasq.pid
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/dnsmasq/run
   ```

4. Start the service:
   ```bash
   sv up dnsmasq
   ```

### Example: postfix Mail Server

1. Create the service directory:
   ```bash
   mkdir -p /etc/service/postfix
   ```

2. Create the run script (`/etc/service/postfix/run`):
   ```bash
   #!/bin/sh
   exec /usr/sbin/postfix start-fg
   ```

3. Make it executable:
   ```bash
   chmod +x /etc/service/postfix/run
   ```

4. Start the service:
   ```bash
   sv up postfix
   ```

## Service Dependencies

runit doesn't have built-in dependency management, but you can implement it in your run scripts:

### Example: Service with Dependencies

To ensure that PostgreSQL starts before your web application:

1. Create a dependency check in your web app's run script:
   ```bash
   #!/bin/sh
   # Wait for PostgreSQL to be ready
   while ! su - postgres -c "psql -c 'SELECT 1'" &>/dev/null; do
       echo "Waiting for PostgreSQL..."
       sleep 1
   done
   
   # Start the web app
   exec /usr/bin/my-web-app
   ```

2. Or use a more sophisticated approach with `sv wait`:
   ```bash
   #!/bin/sh
   # Wait for postgresql service to be up
   sv wait /etc/service/postgresql
   
   # Start the web app
   exec /usr/bin/my-web-app
   ```

## Service Logging

runit automatically captures stdout and stderr from your service's run script. Logs are stored in:

```
/etc/service/<service-name>/log/
├── main/
│   ├── current  # Current log file (symlink)
│   └── <timestamp>  # Archived log files
└── state
```

To view logs:
```bash
# View current logs
sv log <service>

# View log files directly
tail -f /etc/service/<service>/log/main/current

# View all log files
ls -la /etc/service/<service>/log/main/
```

To configure log rotation, create a `log/run` script:

```bash
#!/bin/sh
exec svlogd -tt /var/log/<service>
```

This will write logs to `/var/log/<service>` with timestamps and rotation.

## Service Control

### Starting and Stopping Services

```bash
# Start a service
sv up <service>

# Stop a service
sv down <service>

# Restart a service
sv restart <service>

# Check service status
sv status <service>

# Check if service is running
sv status <service> | grep -q running
```

### Managing All Services

```bash
# Start all services
sv up /etc/service/*

# Stop all services
sv down /etc/service/*

# Restart all services
sv restart /etc/service/*

# Check status of all services
sv status /etc/service/*
```

### Enabling and Disabling Services

To enable a service at boot:
```bash
ln -s /etc/service/<service> /etc/service/<service>
```

To disable a service:
```bash
rm /etc/service/<service>
```

## Initial Service Setup

After installation, you need to set up all the services:

```bash
# Create service directories
for service in sshd nginx postgresql redis samba nmbd postfix dnsmasq chrony cronie rsyslog fail2ban; do
    mkdir -p /etc/service/${service}
    # Copy run scripts from this directory
    cp /usr/local/notlfs/profiles/server/services/runit/${service}/run /etc/service/${service}/run
    chmod +x /etc/service/${service}/run
done

# Initialize PostgreSQL database
su - postgres -c "initdb -D /var/lib/postgresql/data"

# Start all services
sv up /etc/service/*

# Check status
sv status /etc/service/*
```

## Using systemd Instead

If you choose to use systemd instead of runit, the service management is different:

```bash
# Enable services
for service in sshd nginx postgresql redis samba postfix dnsmasq chrony cronie rsyslog fail2ban; do
    systemctl enable ${service}
done

# Start services
for service in sshd nginx postgresql redis samba postfix dnsmasq chrony cronie rsyslog fail2ban; do
    systemctl start ${service}
done

# Check status
systemctl status sshd nginx postgresql
```

systemd automatically handles all dependencies between services.
EOF
    
    # Create config files
    cat > "${profile_dir}/config/server.conf" << 'EOF'
# NotLFS Server Profile Configuration
# =================================

# Build options
BUILD_OPTIMIZATION="-O2 -pipe"
STRIP_DEBUG="false"
KEEP_SOURCES="false"

# System options
HOSTNAME="notlfs-server"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"

# Network options
ENABLE_NETWORK="true"
NETWORK_INTERFACES="eth0"
USE_DHCP="true"
NAMESERVERS="8.8.8.8 8.8.4.4"
ENABLE_IPV6="true"

# Security options
ENABLE_HARDENING="true"
STACK_PROTECTOR="true"
FORTIFY_SOURCE="true"
RELRO="true"
ASLR="true"
PIE="true"
FIREWALL="iptables"

# Init system
INIT_SYSTEM="runit"

# Package options
INSTALL_DOCS="false"
INSTALL_MAN_PAGES="false"
INSTALL_GUI="false"

# Server options
SERVER_TYPE="web"
WEB_SERVER="nginx"
DATABASE="postgresql"
FILE_SERVER="samba"
MAIL_SERVER="postfix"
DNS_SERVER="dnsmasq"
MONITORING="sysstat"
LOGGING="rsyslog"
SECURITY="fail2ban"
TIME_SYNC="chrony"
CRON="cronie"

# User options
ROOT_PASSWORD="changeme"
CREATE_USER="false"
USER_NAME="admin"
USER_GROUPS="wheel,adm"
USER_PASSWORD="changeme"

# Service options
ENABLE_SSH="true"
SSH_PORT="22"
ENABLE_WEB="true"
WEB_PORT="80"
ENABLE_HTTPS="true"
HTTPS_PORT="443"
ENABLE_DATABASE="true"
ENABLE_FILE_SERVER="true"
ENABLE_MAIL="true"
ENABLE_DNS="true"
ENABLE_MONITORING="true"
ENABLE_LOGGING="true"
ENABLE_SECURITY="true"
ENABLE_TIME_SYNC="true"
ENABLE_CRON="true"
EOF
    
    # Create hooks
    cat > "${profile_dir}/hooks/pre-build.sh" << 'EOF'
#!/bin/bash
# Server Profile - Pre-Build Hook

set -e

echo "=== Server Profile: Pre-Build Hook ==="

# Set standard optimization
if [ -z "$OPTIMIZATION" ]; then
    export OPTIMIZATION="-O2 -pipe"
    echo "Set optimization: $OPTIMIZATION"
fi

# Disable GUI
export ENABLE_GUI="false"
echo "GUI disabled"

# Disable documents
export INSTALL_DOCS="false"
echo "Documentation disabled (for size)"

# Set server type
export SERVER_TYPE="web"
echo "Server type: $SERVER_TYPE"

# Set hostname
export HOSTNAME="notlfs-server"

# Enable server features
export ENABLE_SERVER="true"
echo "Server features enabled"

echo "=== Server Profile: Pre-Build Complete ==="
EOF
    chmod +x "${profile_dir}/hooks/pre-build.sh"
    
    cat > "${profile_dir}/hooks/post-install.sh" << 'EOF'
#!/bin/bash
# Server Profile - Post-Install Hook

set -e

echo "=== Server Profile: Post-Install Hook ==="

# Create /etc/issue
cat > ${LFS}/etc/issue << 'ISSUE'
NotLFS Server \r (\n)
Kernel \r on an \m
ISSUE

# Create /etc/motd
cat > ${LFS}/etc/motd << 'MOTD'
Welcome to NotLFS Server
A production-ready Linux server built from source

System information:
  Distribution: NotLFS Server
  Kernel:       \r
  Uptime:       \u
  Load:         \l

Running services:
  - SSH:       OpenSSH
  - Web:       Nginx
  - Database:  PostgreSQL
  - File:      Samba
  - Mail:      Postfix
  - DNS:       dnsmasq
  - Security:  fail2ban
  - Monitoring: sysstat
  - Logging:   rsyslog

Type 'help' for available commands
MOTD

# Set hostname
echo "notlfs-server" > ${LFS}/etc/hostname

# Create shell profile
cat > ${LFS}/etc/profile << 'PROFILE'
# Server shell profile
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PS1='\u@\h:\w\$ '
export EDITOR=vim

# Add user binaries to PATH
if [ -d /usr/local/bin ]; then
    PATH="/usr/local/bin:$PATH"
fi
PROFILE

# Configure bash
cat > ${LFS}/etc/bashrc << 'BASHRC'
# Server bash configuration
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin
export PS1='\u@\h:\w\$ '
export EDITOR=vim

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# History
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
BASHRC

# Create /etc/fstab
cat > ${LFS}/etc/fstab << 'FSTAB'
# Server fstab
proc    /proc   proc    defaults        0       0
sysfs   /sys    sysfs   defaults        0       0
devpts  /dev/pts devpts  gid=5,mode=620 0       0
tmpfs   /dev/shm tmpfs  defaults        0       0
FSTAB

# Setup networking
mkdir -p ${LFS}/etc/network
cat > ${LFS}/etc/network/interfaces << 'INTERFACES'
# Network interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

# For static IP (uncomment and modify as needed)
#auto eth0
#iface eth0 inet static
#    address 192.168.1.100
#    netmask 255.255.255.0
#    gateway 192.168.1.1
#    dns-nameservers 8.8.8.8 8.8.4.4
INTERFACES

# Setup resolv.conf
cat > ${LFS}/etc/resolv.conf << 'RESOLV'
nameserver 8.8.8.8
nameserver 8.8.4.4
RESOLV

# Setup runit init system
if [ "$INIT_SYSTEM" = "runit" ]; then
    echo "Configuring runit init system for server..."
    
    # Create /etc/service directory
    mkdir -p ${LFS}/etc/service
    
    # Create runit services
    local services=("sshd" "nginx" "postgresql" "redis" "samba" "nmbd" "postfix" "dnsmasq" "chrony" "cronie" "rsyslog" "fail2ban")
    
    for service in "${services[@]}"; do
        mkdir -p ${LFS}/etc/service/${service}/log
        
        # Create run script (placeholder - actual scripts should be more specific)
        cat > ${LFS}/etc/service/${service}/run << RUN
#!/bin/sh
# This is a placeholder. Replace with actual service start command.
# For example, for sshd: exec /usr/sbin/sshd -D
exec /usr/sbin/${service} -D 2>/dev/null || echo "Service ${service} not configured"
RUN
        chmod +x ${LFS}/etc/service/${service}/run
        
        # Create log/run script
        cat > ${LFS}/etc/service/${service}/log/run << LOG
#!/bin/sh
exec svlogd -tt /var/log/${service}
LOG
        chmod +x ${LFS}/etc/service/${service}/log/run
    done
    
    # Create /etc/runit directory structure
    mkdir -p ${LFS}/etc/runit
    mkdir -p ${LFS}/etc/runit/sv
    
    # Create runit configuration
    cat > ${LFS}/etc/runit/rc.conf << 'RC'
#!/bin/sh
# runit rc.conf for NotLFS Server

# Source environment
. /etc/profile

# Set PATH
PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin"
export PATH

# Set umask
umask 022

# Start all services in /etc/service
for i in /etc/service/*; do
    [ -d "$i" ] && ln -sf "$i" /etc/runit/sv/ 2>/dev/null
    [ -d "$i" ] && echo "Starting $(basename $i)..." && sv up "$i" 2>/dev/null || true
done
RC
    chmod +x ${LFS}/etc/runit/rc.conf
    
    # Create inittab symlink
    ln -sf /etc/runit/rc.conf ${LFS}/sbin/init
    
    # Create /run directory
    mkdir -p ${LFS}/run
    
    echo "runit init system configured for server"
fi

# Create var directories
mkdir -p ${LFS}/var/log
mkdir -p ${LFS}/var/cache
mkdir -p ${LFS}/var/lib
mkdir -p ${LFS}/var/run
mkdir -p ${LFS}/var/spool

# Create tmp directory
mkdir -p ${LFS}/tmp
chmod 1777 ${LFS}/tmp

# Create home directory
mkdir -p ${LFS}/home

# Create root home directory
mkdir -p ${LFS}/root
chmod 700 ${LFS}/root

# Setup timezone
if [ -f ${LFS}/usr/share/zoneinfo/UTC ]; then
    ln -sf /usr/share/zoneinfo/UTC ${LFS}/etc/localtime
    echo "UTC" > ${LFS}/etc/timezone
fi

# Setup locale
mkdir -p ${LFS}/etc/default
cat > ${LFS}/etc/default/locale << 'LOCALE'
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
LOCALE

# Setup SSH configuration
mkdir -p ${LFS}/etc/ssh
cat > ${LFS}/etc/ssh/sshd_config << 'SSHD'
# NotLFS Server SSH Configuration

# Listen on all interfaces
ListenAddress 0.0.0.0

# Port
Port 22

# Protocol
Protocol 2

# Host keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication yes
PermitRootLogin yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Security
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
LogLevel INFO
SyslogFacility AUTH

# Subsystem
Subsystem sftp /usr/lib/ssh/sftp-server

# Accept environment
AcceptEnv LANG LC_*

# Use PAM
UsePAM yes
SSHD

# Generate SSH host keys
if [ ! -f ${LFS}/etc/ssh/ssh_host_rsa_key ]; then
    chmod 700 ${LFS}/etc/ssh
    ssh-keygen -A -t rsa,ecdsa,ed25519 -f ${LFS}/etc/ssh/ 2>/dev/null || true
fi

# Setup Nginx configuration
mkdir -p ${LFS}/etc/nginx
mkdir -p ${LFS}/etc/nginx/conf.d
mkdir -p ${LFS}/etc/nginx/sites-available
mkdir -p ${LFS}/etc/nginx/sites-enabled

cat > ${LFS}/etc/nginx/nginx.conf << 'NGINX'
# NotLFS Server Nginx Configuration

user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log;
pid        /var/run/nginx.pid;

Events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;
    tcp_nodelay        on;
    keepalive_timeout  65;
    types_hash_max_size 2048;

    include             /etc/nginx/conf.d/*.conf;
    include             /etc/nginx/sites-enabled/*;

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
NGINX

# Create default site
cat > ${LFS}/etc/nginx/conf.d/default.conf << 'DEFAULT'
server {
    listen       80;
    server_name  _;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    error_page  404 /404.html;
    location = /404.html {
        root   /usr/share/nginx/html;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
DEFAULT

# Create Nginx HTML directory
mkdir -p ${LFS}/usr/share/nginx/html
cat > ${LFS}/usr/share/nginx/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>NotLFS Server</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        h1 { color: #333; }
        p { color: #666; }
    </style>
</head>
<body>
    <h1>Welcome to NotLFS Server</h1>
    <p>This is the default page for Nginx on NotLFS Server.</p>
    <p>Your server is running successfully!</p>
</body>
</html>
HTML

# Setup PostgreSQL configuration
mkdir -p ${LFS}/etc/postgresql
mkdir -p ${LFS}/var/lib/postgresql

cat > ${LFS}/etc/postgresql/postgresql.conf << 'PGSQL'
# NotLFS Server PostgreSQL Configuration

# Data directory
data_directory = '/var/lib/postgresql/data'

# Listen on all interfaces
listen_addresses = '*'

# Port
port = 5432

# Maximum connections
max_connections = 100

# Memory settings
shared_buffers = 128MB
work_mem = 16MB
effective_cache_size = 384MB
maintenance_work_mem = 64MB

# WAL settings
wal_buffers = 16MB
checkpoint_segments = 8
checkpoint_completion_target = 0.9

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'pg_log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 10MB

# Authentication
authentication_timeout = 1min

# Security
tcp_keepalives_idle = 60
tcp_keepalives_interval = 10
tcp_keepalives_count = 5
PGSQL

# Create PostgreSQL data directory
mkdir -p ${LFS}/var/lib/postgresql/data
chown 1001:1001 ${LFS}/var/lib/postgresql/data 2>/dev/null || true

# Setup Samba configuration
mkdir -p ${LFS}/etc/samba
cat > ${LFS}/etc/samba/smb.conf << 'SAMBA'
# NotLFS Server Samba Configuration

[global]
    workgroup = WORKGROUP
    server string = NotLFS Server
    netbios name = notlfs-server
    security = user
    map to guest = Bad User
    dns proxy = no

[homes]
    comment = Home Directories
    browseable = no
    read only = no
    create mask = 0700
    directory mask = 0700

[public]
    comment = Public Share
    path = /srv/samba/public
    browseable = yes
    read only = no
    guest ok = yes
    create mask = 0775
    directory mask = 0775
SAMBA

# Create Samba directories
mkdir -p ${LFS}/srv/samba/public
chmod 777 ${LFS}/srv/samba/public

# Setup Postfix configuration
mkdir -p ${LFS}/etc/postfix
cat > ${LFS}/etc/postfix/main.cf << 'POSTFIX'
# NotLFS Server Postfix Configuration

# My hostname
myhostname = notlfs-server

# My domain
mydomain = local

# My origin
myorigin = \$myhostname

# Inet interfaces
inet_interfaces = all
inet_protocols = ipv4

# My destination
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain

# Unknown local recipient rejection
unknown_local_recipient_reject_code = 550

# Mynetworks
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128

# Relay host
#relayhost = [smtp.example.com]

# Mail name
mail_name = NotLFS Server

# Aliases
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases

# Home mailbox
home_mailbox = Maildir/

# SMTPd restrictions
smtpd_banner = \$myhostname ESMTP
smtpd_helo_restrictions = permit_mynetworks, reject_invalid_helo_hostname, permit
smtpd_recipient_restrictions = permit_mynetworks, reject_unauth_destination, permit
smtpd_data_restrictions = reject_unauth_pipelining
smtpd_command_filter = 

# TLS parameters
#smtpd_tls_cert_file = /etc/ssl/certs/ssl-cert-snakeoil.pem
#smtpd_tls_key_file = /etc/ssl/private/ssl-cert-snakeoil.key
#smtpd_use_tls = yes
#smtpd_tls_security_level = may
POSTFIX

cat > ${LFS}/etc/aliases << 'ALIASES'
# NotLFS Server Aliases

# Root email
root: admin@localhost

# Default aliases
postmaster: root
mailer-daemon: root
nobody: root
hostmaster: root
usenet: root
news: root
list: root
www: root
ftp: root
abuse: root
ALIASES

# Setup dnsmasq configuration
mkdir -p ${LFS}/etc/dnsmasq
cat > ${LFS}/etc/dnsmasq.conf << 'DNSMASQ'
# NotLFS Server dnsmasq Configuration

# Listen on all interfaces
listen-address=0.0.0.0

# Listen on localhost
listen-address=127.0.0.1

# Bind to specific interface (optional)
#bind-interfaces

# DNS servers to forward queries to
server=8.8.8.8
server=8.8.4.4

# Local domain
#domain=example.com

# Local DNS records
#address=/example.com/192.168.1.100

# DHCP range (optional)
#dhcp-range=192.168.1.100,192.168.1.200,12h

# DHCP options
#dhcp-option=option:router,192.168.1.1
#dhcp-option=option:dns-server,192.168.1.100

# Log queries
log-queries

# Log DNS queries to syslog
log-dhcp

# Don't forward private reverse lookups
no-resolv

# Cache size
cache-size=1000
DNSMASQ

# Setup chrony configuration
cat > ${LFS}/etc/chrony.conf << 'CHRONY'
# NotLFS Server chrony Configuration

# Use public NTP servers
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

# Record the rate at which the system clock gains/losses time
driftfile /var/lib/chrony/chrony.drift

# Allow the system clock to be stepped in the first three updates
# if its offset is larger than 1 second
makestep 1.0 3

# Enable kernel synchronization of the real-time clock (RTC)
rtcsync

# Allow client queries from local network
#allow 192.168.0.0/16

# Serve time even if not synchronized to a time source
#local stratum 10

# Specify directory for log files
logdir /var/log/chrony

# Select which information is logged
log tracking measurements statistics

# Log only once per step
logchange 0.5
CHRONY

# Create chrony directory
mkdir -p ${LFS}/var/lib/chrony

# Setup rsyslog configuration
mkdir -p ${LFS}/etc/rsyslog.d
cat > ${LFS}/etc/rsyslog.conf << 'RSYSLOG'
# NotLFS Server rsyslog Configuration

# Modules
module(load="imuxsock")
module(load="imklog")

# Set default timestamp format
\$ActionFileDefaultTemplate RSYSLOG_FileFormat

# Enable high-precision timestamps
\$ActionHighPrecisionTimestamps on

# Log all messages to /var/log/syslog
*.*    /var/log/syslog

# Log kernel messages to /var/log/kern.log
kern.*    /var/log/kern.log

# Log auth messages to /var/log/auth.log
auth,authpriv.*    /var/log/auth.log

# Log cron messages to /var/log/cron.log
cron.*    /var/log/cron.log

# Log mail messages to /var/log/mail.log
mail.*    /var/log/mail.log

# Log emergency messages to all users
*.emerg    :omusrmsg:*

# Don't log to /dev/console
*.*    stop
RSYSLOG

# Setup fail2ban configuration
mkdir -p ${LFS}/etc/fail2ban
cat > ${LFS}/etc/fail2ban/jail.local << 'FAIL2BAN'
# NotLFS Server fail2ban Configuration

[DEFAULT]
# Ban time in seconds (1 hour)
bantime = 3600

# Find time in seconds (10 minutes)
findtime = 600

# Max retry count
maxretry = 5

# Backend
backend = auto

# Used to store the state
usedns = warning

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 5

[nginx-botsearch]
enabled = true
port = http,https
filter = nginx-botsearch
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-nohome]
enabled = true
port = http,https
filter = nginx-nohome
logpath = /var/log/nginx/access.log
maxretry = 2

[postfix]
enabled = true
port = smtp,submission
filter = postfix
logpath = /var/log/mail.log
maxretry = 3
FAIL2BAN

# Setup logrotate configuration
mkdir -p ${LFS}/etc/logrotate.d
cat > ${LFS}/etc/logrotate.conf << 'LOGROTATE'
# NotLFS Server logrotate Configuration

# Weekly rotation
weekly

# Rotate 4 weeks
rotate 4

# Create new log files after rotation
create

# Use date as suffix
dateext

# Compress log files
compress

# Delay compression until next rotation
delaycompress

# Don't rotate if empty
notifempty

# Ignore errors
missingok

# Don't rotate if no rotation is forced
nomail

# Default drop privileges
su root adm

# Include drop-ins
include /etc/logrotate.d
LOGROTATE

# Create logrotate for nginx
cat > ${LFS}/etc/logrotate.d/nginx << 'NGINXLOG'
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 nginx adm
    sharedscripts
    postrotate
        if [ -f /etc/service/nginx/run ]; then
            sv restart nginx
        elif [ -f /etc/s6/nginx/run ]; then
            s6-rc -d change nginx
            s6-rc -u change nginx
        elif systemctl is-active --quiet nginx 2>/dev/null; then
            systemctl reload nginx
        fi
    endscript
}
NGINXLOG

# Create logrotate for postgresql
cat > ${LFS}/etc/logrotate.d/postgresql << 'PGSQLLOG'
/var/log/postgresql/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 postgres postgres
    sharedscripts
    postrotate
        if [ -f /etc/service/postgresql/run ]; then
            su - postgres -c "pg_ctl reload"
        elif [ -f /etc/s6/postgresql/run ]; then
            s6-rc -d change postgresql
            s6-rc -u change postgresql
        elif systemctl is-active --quiet postgresql 2>/dev/null; then
            systemctl reload postgresql
        fi
    endscript
}
PGSQLLOG

# Setup iptables configuration
mkdir -p ${LFS}/etc/iptables
cat > ${LFS}/etc/iptables/rules.v4 << 'IPTABLES'
# NotLFS Server iptables Configuration

# Flush all rules
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established connections
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP
-A INPUT -p tcp --dport 80 -j ACCEPT

# Allow HTTPS
-A INPUT -p tcp --dport 443 -j ACCEPT

# Allow SMTP
-A INPUT -p tcp --dport 25 -j ACCEPT

# Allow DNS
-A INPUT -p tcp --dport 53 -j ACCEPT
-A INPUT -p udp --dport 53 -j ACCEPT

# Allow Samba
-A INPUT -p tcp --dport 139 -j ACCEPT
-A INPUT -p tcp --dport 445 -j ACCEPT
-A INPUT -p udp --dport 137 -j ACCEPT
-A INPUT -p udp --dport 138 -j ACCEPT

# Allow NFS
-A INPUT -p tcp --dport 2049 -j ACCEPT
-A INPUT -p udp --dport 2049 -j ACCEPT

# Allow PostgreSQL
-A INPUT -p tcp --dport 5432 -j ACCEPT

# Allow Redis
-A INPUT -p tcp --dport 6379 -j ACCEPT

# Allow ping
-A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# Log dropped packets
-A INPUT -j LOG --log-prefix "IPTables-Dropped: " --log-level 4

# Drop everything else
-A INPUT -j DROP

COMMIT
IPTABLES

# Create iptables restore script
cat > ${LFS}/usr/local/bin/iptables-restore.sh << 'RESTORE'
#!/bin/sh
# Restore iptables rules

iptables-restore < /etc/iptables/rules.v4
RESTORE
chmod +x ${LFS}/usr/local/bin/iptables-restore.sh

# Create var directories for services
mkdir -p ${LFS}/var/lib/postgresql
mkdir -p ${LFS}/var/lib/redis
mkdir -p ${LFS}/var/lib/chrony
mkdir -p ${LFS}/var/log/nginx
mkdir -p ${LFS}/var/log/postgresql
mkdir -p ${LFS}/var/log/samba
mkdir -p ${LFS}/var/log/postfix
mkdir -p ${LFS}/var/log/chrony
mkdir -p ${LFS}/var/log/fail2ban
mkdir -p ${LFS}/var/log/syslog
mkdir -p ${LFS}/var/spool/postfix
mkdir -p ${LFS}/var/spool/samba

# Create srv directory
mkdir -p ${LFS}/srv/samba

# Setup timezone
if [ -f ${LFS}/usr/share/zoneinfo/UTC ]; then
    ln -sf /usr/share/zoneinfo/UTC ${LFS}/etc/localtime
    echo "UTC" > ${LFS}/etc/timezone
fi

echo "=== Server Profile: Post-Install Complete ==="
echo ""
echo "Server setup complete!"
echo ""
echo "To start services with runit:"
echo "  sv up /etc/service/*"
echo ""
echo "To check service status:"
echo "  sv status /etc/service/*"
echo ""
echo "To enable services at boot (runit):"
echo "  Services in /etc/service/ are automatically started at boot"
echo ""
echo "To configure services:"
echo "  Edit /etc/service/<service>/run"
echo "  Edit configuration files in /etc/"
echo ""
echo "Default services included:"
echo "  - sshd (SSH server on port 22)"
echo "  - nginx (Web server on port 80)"
echo "  - postgresql (Database on port 5432)"
echo "  - redis (Key-value store on port 6379)"
echo "  - samba (File server)"
echo "  - postfix (Mail server)"
echo "  - dnsmasq (DNS server)"
echo "  - chrony (Time synchronization)"
echo "  - cronie (Cron daemon)"
echo "  - rsyslog (System logging)"
echo "  - fail2ban (Intrusion prevention)"
echo ""
echo "Access your server:"
echo "  SSH: ssh root@<server-ip>"
echo "  Web: http://<server-ip>"
echo ""
echo "Default credentials:"
echo "  Username: root"
echo "  Password: ${ROOT_PASSWORD:-changeme}"
echo ""
echo "IMPORTANT: Change all default passwords after installation!"
EOF
    chmod +x "${profile_dir}/hooks/post-install.sh"
    
    log_info "Server profile created successfully"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_section "NotLFS Profiles Creation"
    
    # Create all four profiles
    create_minimal_profile
    create_base_profile
    create_desktop_profile
    create_server_profile
    
    # Create a summary file
    cat > "${PROFILES_DIR}/README.md" << 'EOF'
# NotLFS Build Profiles

This directory contains the four build profiles for the NotLFS framework:

## Available Profiles

| Profile | Description | Init System | Build Time | Disk Space | Use Case |
|---------|-------------|-------------|------------|------------|----------|
| **minimal** | Absolute minimal system | s6 | 30-60 min | 300-500 MB | Embedded, containers, rescue |
| **base** | Complete system with dev tools | s6-rc | 2-4 hours | 1.5-2.5 GB | Workstations, general servers |
| **desktop** | Full KDE Plasma desktop | s6-rc | 6-12 hours | 8-15 GB | Desktop computers, GUI workstations |
| **server** | Server with web, DB, file services | runit | 3-6 hours | 2-4 GB | Production servers, cloud instances |

## Profile Structure

Each profile directory contains:

```
profile-name/
├── profile.xml          # Main profile definition (XML format)
├── packages.list        # List of packages to install
├── README.md            # Profile documentation
├── config/              # Configuration files
│   └── <profile>.conf   # Default configuration
├── services/            # Init system service definitions
│   └── <init>/          # Service definitions for specific init system
│       └── README.md    # Service documentation
└── hooks/               # Build hooks
    ├── pre-build.sh      # Pre-build hook
    └── post-install.sh   # Post-install hook
```

## Quick Start

### Build with a profile

```bash
# Minimal profile
./notlfs.sh -p minimal

# Base profile
./notlfs.sh -p base

# Desktop profile (KDE Plasma)
./notlfs.sh -p desktop

# Server profile
./notlfs.sh -p server
```

### Specify init system

```bash
# Minimal with s6-rc
./notlfs.sh -p minimal -i s6-rc

# Base with systemd
./notlfs.sh -p base -i systemd

# Desktop with systemd (recommended for best desktop integration)
./notlfs.sh -p desktop -i systemd

# Server with runit (default)
./notlfs.sh -p server -i runit
```

### Build modes

```bash
# Interactive mode (recommended for desktop)
./notlfs.sh -p desktop -m interactive

# Auto mode (unattended)
./notlfs.sh -p server -m auto

# Manual mode (step-by-step)
./notlfs.sh -p minimal -m manual
```

## Profile Selection Guide

### Choose **minimal** if:
- You need the smallest possible Linux system
- You're building for embedded devices
- You're creating container images
- You want maximum control over what's installed
- You're building a rescue/recovery system

### Choose **base** if:
- You need a complete Linux system for general use
- You're setting up a development workstation
- You want a solid foundation for further customization
- You need development tools and networking
- You're unsure which profile to choose

### Choose **desktop** if:
- You need a graphical desktop environment
- You're building a workstation with GUI
- You want KDE Plasma specifically
- You need multimedia support
- You want productivity applications (office, browser, etc.)

### Choose **server** if:
- You're setting up a production server
- You need web server capabilities
- You need database support
- You need file sharing (Samba, NFS)
- You're deploying to cloud instances
- You want a headless (no GUI) system

## Customizing Profiles

### Create a custom profile

To create a custom profile that inherits from an existing one:

```bash
# Create a new profile directory
mkdir -p ${PROFILES_DIR}/my-profile

# Create profile.xml
cat > ${PROFILES_DIR}/my-profile/profile.xml << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<profile>
    <name>my-profile</name>
    <description>My custom profile based on base</description>
    <inherits>base</inherits>
    <!-- Additional profile settings -->
</profile>
